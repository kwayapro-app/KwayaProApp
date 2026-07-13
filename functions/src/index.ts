import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret, projectID} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();

// ── Secrets (set via `firebase functions:secrets:set`) ───────────
const mtnApiUser     = defineSecret("MTN_API_USER");
const mtnApiKey      = defineSecret("MTN_API_KEY");
const mtnSubKey      = defineSecret("MTN_SUBSCRIPTION_KEY");
const mtnWebhookSec  = defineSecret("MTN_WEBHOOK_SECRET");
const mtnTargetEnv   = defineSecret("MTN_TARGET_ENV");
// const airtelClientId = defineSecret("AIRTEL_CLIENT_ID");
// const airtelClientSec = defineSecret("AIRTEL_CLIENT_SECRET");
// const airtelWebhookSec = defineSecret("AIRTEL_WEBHOOK_SECRET");
const r2AccountId    = defineSecret("R2_ACCOUNT_ID");
const r2AccessKey    = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretKey    = defineSecret("R2_SECRET_ACCESS_KEY");
const r2BucketName   = defineSecret("R2_BUCKET_NAME");

// ── R2 Presigned URL Generation ─────────────────────────────────
export { getR2PresignedUploadChannel } from "./audio/presignedUrlEndpoint";

// Legacy presigned URL function (kept for backward compatibility)
export const getPresignedUrl = onRequest(
  { cors: true, secrets: [r2AccountId, r2BucketName, r2AccessKey, r2SecretKey] },
  async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) { res.status(401).json({error: "Unauthorized"}); return; }

    const { choirId, songId, sectionId, voicePart, mimeType } = req.body;
    if (!choirId || !songId || !sectionId || !voicePart) {
      res.status(400).json({error: "Missing required fields"}); return;
    }

    const objectKey = `choirs/${choirId}/songs/${songId}/sections/${sectionId}/${voicePart}.${mimeType?.split("/").pop() || "m4a"}`;

    const r2ActId = r2AccountId.value();
    const r2Bucket = r2BucketName.value();
    const r2Access = r2AccessKey.value();
    const r2Secret = r2SecretKey.value();

    if (!r2ActId || !r2Bucket || !r2Access || !r2Secret) {
      logger.warn("R2 not configured, falling back to Firebase Storage");
      res.json({ fallback: true, objectKey });
      return;
    }

    const endpoint = `https://${r2ActId}.r2.cloudflarestorage.com/${r2Bucket}/${objectKey}`;
    const expiry = Math.floor(Date.now() / 1000) + 900;

    const crypto = require("crypto");
    const signature = crypto.createHmac("sha256", r2Secret)
      .update(`PUT\n\n${mimeType || "audio/m4a"}\n${expiry}\n/${r2Bucket}/${objectKey}`)
      .digest("hex");

    const presignedUrl = `${endpoint}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=${r2Access}%2F${expiry}%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=${new Date().toISOString().replace(/[:-]/g, "").split(".")[0]}Z&X-Amz-Expires=900&X-Amz-Signature=${signature}`;

    res.json({ presignedUrl, objectKey, expiresIn: 900 });
  },
);

// ── Audio Upload Confirmation ───────────────────────────────────
export const confirmAudioUpload = onDocumentCreated("audio_parts/{partId}", async (event) => {
  const part = event.data?.data();
  if (!part) return;

  const songId = part.songId;
  const sectionId = part.sectionId;

  await db.collection("song_sections").doc(sectionId).update({ status: "ready" });

  const songDoc = await db.collection("songs").doc(songId).get();
  const choirId = songDoc.data()?.choirId;
  if (choirId) {
    const choirIdStr = choirId as string;
    const members = await db.collection("choir_memberships")
      .where("choirId", "==", choirIdStr)
      .where("defaultVoicePart", "==", part.voicePart)
      .get();

    const tokens: string[] = [];
    for (const m of members.docs) {
      const userDoc = await db.collection("users").doc(m.data().userId).get();
      const token = userDoc.data()?.fcmToken as string | undefined;
      if (token) tokens.push(token);
    }

    if (tokens.length > 0) {
      const songTitle = songDoc.data()?.title || "Unknown";
      const sectionTitle = part.sectionTitle || sectionId;
      const message = {
        notification: { title: "New Audio Uploaded", body: `${part.voicePart} part for "${sectionTitle}" of "${songTitle}"` },
        tokens,
      };
      try { await admin.messaging().sendEachForMulticast(message); }
      catch (e) { logger.warn("FCM send failed", e); }
    }
  }
});

// ── Rehearsal Created Notification ──────────────────────────────
export const onRehearsalCreated = onDocumentCreated("rehearsal_sessions/{sessionId}", async (event) => {
  const session = event.data?.data();
  if (!session) return;

  const choirId = session.choirId as string;
  const members = await db.collection("choir_memberships").where("choirId", "==", choirId).get();

  const tokens: string[] = [];
  for (const m of members.docs) {
    const userDoc = await db.collection("users").doc(m.data().userId).get();
    const token = userDoc.data()?.fcmToken as string | undefined;
    if (token) tokens.push(token);
  }

  if (tokens.length > 0) {
    const message = {
      notification: { title: "New Rehearsal Scheduled", body: `${session.date} at ${session.time} - ${session.location || "TBD"}` },
      data: { type: "rehearsal_created", sessionId: event.params.sessionId, choirId },
      tokens,
    };
    try { await admin.messaging().sendEachForMulticast(message); }
    catch (e) { logger.warn("FCM rehearsal notification failed", e); }
  }
});

// ── Rehearsal 24hr Reminder ────────────────────────────────────
// CHORISTER AUDIT FIX: this used to notify every member of the choir
// regardless of RSVP status — someone who'd already responded "Coming" or
// "Not Coming" still got a reminder as if they'd never RSVPed, which is
// what the reminder is supposed to be *for*. Now excludes anyone with an
// attendance doc whose rsvp is 'coming' or 'notComing' for this session
// (RSVPStatus, enums.dart) — 'pending'/no doc at all both still count as
// "un-RSVPed" and get reminded. Also fixed the notification body, which
// interpolated the raw Firestore Timestamp object (`${session.date}`)
// instead of a formatted date.
export const rehearsalReminder = onSchedule("0 * * * *", async (event) => {
  const now = Timestamp.now();
  const tomorrow = new Date(now.toDate().getTime() + 24 * 60 * 60 * 1000);
  const endWindow = new Date(tomorrow.getTime() + 60 * 60 * 1000);

  const sessions = await db.collection("rehearsal_sessions")
    .where("date", ">=", Timestamp.fromDate(tomorrow))
    .where("date", "<=", Timestamp.fromDate(endWindow))
    .get();

  for (const doc of sessions.docs) {
    const session = doc.data();
    const choirId = session.choirId as string;
    const members = await db.collection("choir_memberships").where("choirId", "==", choirId).get();

    const attendanceDocs = await db.collection("attendance").where("sessionId", "==", doc.id).get();
    const respondedUserIds = new Set(
      attendanceDocs.docs
        .filter((a) => a.data().rsvp === "coming" || a.data().rsvp === "notComing")
        .map((a) => a.data().userId as string),
    );

    const tokens: string[] = [];
    for (const m of members.docs) {
      const userId = m.data().userId as string;
      if (respondedUserIds.has(userId)) continue;
      const userDoc = await db.collection("users").doc(userId).get();
      const token = userDoc.data()?.fcmToken as string | undefined;
      if (token) tokens.push(token);
    }

    if (tokens.length > 0) {
      const dateObj = (session.date as Timestamp).toDate();
      const formattedDate = dateObj.toLocaleDateString("en-US", {
        weekday: "long", month: "long", day: "numeric",
      });
      const message = {
        notification: { title: "Rehearsal Tomorrow!", body: `Don't forget: ${formattedDate} at ${session.time}` },
        data: { type: "rehearsal_reminder", sessionId: doc.id, choirId },
        tokens,
      };
      try { await admin.messaging().sendEachForMulticast(message); }
      catch (e) { logger.warn("FCM reminder failed", e); }
    }
  }
});

// Reverts a director grant (guest-link or direct assignment) back to
// whatever role/permissions the member held before it, keyed by
// directorSessionId so a member directing two different sessions
// sequentially never has an earlier session's revert clobber a later
// grant. Shared by checkGuestTokenExpiry (session end) and
// onRehearsalSessionDirectorChanged (reassignment before session start).
async function revokeDirectorGrant(choirId: string, uid: string, sessionId: string): Promise<void> {
  const membershipRef = db.collection("choir_memberships").doc(`${choirId}_${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(membershipRef);
    const data = snap.data();
    if (!data || data.directorSessionId !== sessionId) return;
    tx.update(membershipRef, {
      role: data.directorPriorRole ?? "chorister",
      permissions: data.directorPriorPermissions ?? [],
      directorSessionId: FieldValue.delete(),
      directorPriorRole: FieldValue.delete(),
      directorPriorPermissions: FieldValue.delete(),
    });
  });
}

// ── Guest Token Expiry / Director Session Expiry ─────────────────
// SECURITY FIX (Leader/Director audit): previously only cleared the
// session doc's own guestToken/guestTokenExpiry/isGuestDirector fields —
// confirmed live that the guest's actual elevated choir_memberships doc
// (role: "director") was never touched, so their access never actually
// expired. Now also reverts the director's membership via
// revokeDirectorGrant, and does so for BOTH guest-link grants and direct
// Leader assignments (rehearsal_sessions.directorId with no guest token),
// using the same 6pm-day-of-session cutoff for both so a Leader-assigned
// director's access expires when their session ends too — previously
// there was no expiry at all for that path since assigning a director
// never granted anything in the first place (see
// onRehearsalSessionDirectorChanged below).
export const checkGuestTokenExpiry = onSchedule("*/30 * * * *", async () => {
  const now = Timestamp.now();

  const guestSessions = await db.collection("rehearsal_sessions")
    .where("guestTokenExpiry", "<=", now)
    .where("isGuestDirector", "==", true)
    .get();

  for (const doc of guestSessions.docs) {
    const session = doc.data();
    await doc.ref.update({
      guestToken: FieldValue.delete(),
      guestTokenExpiry: FieldValue.delete(),
      isGuestDirector: false,
    });
    // BUG FIX (found live during on-device verification): joinAsGuestDirector
    // never updates rehearsal_sessions.directorId to the guest's uid — that
    // field still holds whatever it was at session creation (the Leader's
    // own uid, since the Leader is always the creator). Using
    // session.directorId here silently reverted the LEADER's membership
    // (a no-op, since their directorSessionId never matched) instead of the
    // actual guest's — confirmed live: the guest's role stayed "director"
    // after this ran. The guest's identity is only recorded on their OWN
    // membership doc via directorSessionId, so query for whoever actually
    // holds this session's grant instead of trusting session.directorId.
    const grantees = await db.collection("choir_memberships")
      .where("choirId", "==", session.choirId)
      .where("directorSessionId", "==", doc.id)
      .get();
    for (const granteeDoc of grantees.docs) {
      await revokeDirectorGrant(session.choirId, granteeDoc.data().userId, doc.id);
    }
    logger.info(`Expired guest token for session ${doc.id}`);
  }

  // Directly-assigned (non-guest) directors: same cutoff, driven off the
  // session's own date/time rather than a guestTokenExpiry field, since
  // that path never sets one.
  const assignedSessions = await db.collection("rehearsal_sessions")
    .where("directorAccessExpiry", "<=", now)
    .where("directorAccessRevoked", "==", false)
    .get();

  for (const doc of assignedSessions.docs) {
    const session = doc.data();
    // Same query-based lookup as the guest path above rather than trusting
    // session.directorId directly — more robust against any future drift
    // between the two, even though onRehearsalSessionDirectorChanged does
    // keep directorId in sync for this (non-guest) path today.
    const grantees = await db.collection("choir_memberships")
      .where("choirId", "==", session.choirId)
      .where("directorSessionId", "==", doc.id)
      .get();
    for (const granteeDoc of grantees.docs) {
      await revokeDirectorGrant(session.choirId, granteeDoc.data().userId, doc.id);
    }
    await doc.ref.update({ directorAccessRevoked: true });
    logger.info(`Expired assigned-director access for session ${doc.id}`);
  }
});

// ── Session-Scoped Director Assignment ───────────────────────────
// FUNCTIONAL FIX (Leader/Director audit): rehearsals_screen.dart's
// "assign a director" picker (_selectedDirectorId) only ever set a
// cosmetic directorId field on the rehearsal_sessions doc — confirmed
// live that firestore.rules' hasAnyRole(choirId, ['leader','director'])
// checks the choir_memberships.role field exclusively, which this picker
// never touched, so the assigned member got zero actual director
// capability (no attendance marking, no audio upload) despite the Leader
// UI implying otherwise. This mirrors joinAsGuestDirector's grant (same
// directorPriorRole/directorPriorPermissions/directorSessionId shape) but
// triggers directly off the session write instead of a shared link/token,
// since the assignee is already an authenticated choir member the Leader
// picked from the member list.
export const onRehearsalSessionDirectorChanged = onDocumentWritten(
  "rehearsal_sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return; // deletion — nothing to grant.

    // Guest-link sessions are granted via joinAsGuestDirector at the
    // moment the guest actually joins, not here — this trigger only
    // handles direct Leader assignment.
    if (after.isGuestDirector) return;

    const choirId = after.choirId as string;
    const sessionId = event.params.sessionId as string;
    const newDirectorId = after.directorId as string | undefined;
    const oldDirectorId = before?.directorId as string | undefined;

    // Set the day-of-session 6pm cutoff (same convention as guest tokens)
    // the expiry sweep above uses, the first time this session gets a
    // real assignment.
    if (newDirectorId && !after.directorAccessExpiry) {
      const sessionDate = (after.date as Timestamp).toDate();
      const expiry = new Date(sessionDate.getFullYear(), sessionDate.getMonth(), sessionDate.getDate());
      expiry.setHours(expiry.getHours() + 18);
      await event.data!.after.ref.update({
        directorAccessExpiry: Timestamp.fromDate(expiry),
        directorAccessRevoked: false,
      });
    }

    if (oldDirectorId && oldDirectorId !== newDirectorId) {
      // Reassigned before the session start (PRD 5.4: "can be changed up
      // to the session start") — the previous assignee loses access to
      // this specific session.
      await revokeDirectorGrant(choirId, oldDirectorId, sessionId);
    }

    if (!newDirectorId || newDirectorId === oldDirectorId) return;

    const membershipRef = db.collection("choir_memberships").doc(`${choirId}_${newDirectorId}`);
    const existingSnap = await membershipRef.get();
    const existingData = existingSnap.data();
    if (!existingData) return; // not a member of this choir — nothing to grant.
    if (existingData.role === "leader") return; // already has full access.

    await membershipRef.update({
      role: "director",
      directorSessionId: sessionId,
      directorPriorRole: existingData.directorPriorRole ?? existingData.role ?? "chorister",
      directorPriorPermissions: existingData.directorPriorPermissions ?? existingData.permissions ?? [],
    });
    logger.info(`Assigned session director: choir=${choirId} session=${sessionId} user=${newDirectorId}`);
  },
);

// ── Song Program Published Notification ─────────────────────────
export const onProgramPublished = onDocumentUpdated("song_programs/{programId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (before?.publishedAt || !after?.publishedAt) return;

  const choirId = after.choirId as string;
  const members = await db.collection("choir_memberships").where("choirId", "==", choirId).get();

  const tokens: string[] = [];
  for (const m of members.docs) {
    const userDoc = await db.collection("users").doc(m.data().userId).get();
    const token = userDoc.data()?.fcmToken as string | undefined;
    if (token) tokens.push(token);
  }

  if (tokens.length > 0) {
    const message = {
      notification: { title: "New Program Published", body: `"${after.eventName}" - Check what to practice!` },
      data: { type: "program_published", programId: event.params.programId, choirId },
      tokens,
    };
    try { await admin.messaging().sendEachForMulticast(message); }
    catch (e) { logger.warn("FCM program notification failed", e); }
  }
});

// ── Webhook auth helper ──────────────────────────────────────────
// TODO(payment-integrity, Phase 3): MTN's actual callback authentication
// mechanism could not be confirmed against an authoritative source —
// momodeveloper.mtn.com and momoapi.mtn.com are both gated/JS-rendered
// portals inaccessible from this environment (see PHASE_3_REPORT.md for the
// exact attempts made). Interim approach: a shared secret embedded as a
// `?key=` query param in the callbackUrl WE construct and hand to MTN in
// initiatePayment. This does not depend on MTN sending any particular
// header we can't verify — MTN must round-trip the exact URL we gave it,
// query string included, to deliver the callback at all. CONFIRM this
// against MTN's real Collections API callback spec before trusting it for
// real production payments; consider also cross-checking transaction status
// via MTN's authenticated GET /requesttopay/{referenceId} endpoint as a
// stronger defense once portal access is available.
function isAuthorizedWebhookRequest(req: { query: Record<string, unknown> }, secretValue: string): boolean {
  if (!secretValue) return false; // fail CLOSED if the secret isn't configured
  const provided = req.query.key;
  return typeof provided === "string" && provided.length > 0 && provided === secretValue;
}

// (Phase 3b: paymentWebhook was removed here. It was dead/orphaned — nothing
// in this codebase ever targeted it, only mtnWebhook was ever wired as the
// real MTN callback destination — see PHASE_3B_REPORT.md Fix A. Deploying
// this removal requires `firebase deploy --only functions`; until that
// deploy runs, the previously-deployed version may still be live and
// reachable.)

// ── Initiate Payment ──────────────────────────────────────────────
export const initiatePayment = onRequest(
  { cors: true, secrets: [mtnApiUser, mtnApiKey, mtnSubKey, mtnTargetEnv, mtnWebhookSec] },
  async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({error: "You must be signed in to do this."});
      return;
    }

    let uid: string;
    try {
      const idToken = authHeader.slice("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (e) {
      logger.warn("initiatePayment: invalid ID token", e);
      res.status(401).json({error: "Your session has expired. Please sign in again."});
      return;
    }

    const { provider, phone, amount, choirId } = req.body;
    if (!provider || !phone || !amount || !choirId) {
      res.status(400).json({error: "Missing required fields"});
      return;
    }

    if (provider !== "mtn") {
      res.status(400).json({error: "Airtel Money is coming soon — MTN Mobile Money is available now."});
      return;
    }

    // Confirm the caller actually belongs to the choir they're paying for —
    // without this, any authenticated user could trigger a real MTN
    // requesttopay (an STK-push-style prompt) against an arbitrary phone
    // number for an arbitrary choirId, at our merchant account's expense.
    const membershipSnap = await db.collection("choir_memberships").doc(`${choirId}_${uid}`).get();
    if (!membershipSnap.exists) {
      res.status(403).json({error: "You are not a member of this choir."});
      return;
    }

    const txRef = `TXN-${choirId}-${Date.now()}`;
    const targetEnv = mtnTargetEnv.value() || "sandbox";

    // MTN's production API host could not be confirmed against an
    // authoritative source in this environment (see the TODO above
    // isAuthorizedWebhookRequest for why). "https://momoapi.mtn.com" is
    // MTN's documented production Collections host per third-party
    // integration references — CONFIRM against MTN's real docs before
    // relying on this for real production payments.
    const baseHost = targetEnv === "production"
      ? "https://momoapi.mtn.com"
      : "https://sandbox.momodeveloper.mtn.com";

    try {
      const tokenResponse = await fetch(
        `${baseHost}/collection/token/`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${Buffer.from(`${mtnApiUser.value()}:${mtnApiKey.value()}`).toString("base64")}`,
            "Ocp-Apim-Subscription-Key": mtnSubKey.value(),
          },
        },
      );
      const tokenData = await tokenResponse.json() as { access_token?: string };
      const accessToken = tokenData.access_token;
      if (!accessToken) {
        res.status(502).json({error: "Failed to get MTN token"});
        return;
      }

      const webhookSecret = mtnWebhookSec.value();
      // Phase 3c: verified this legacy cloudfunctions.net format actually
      // routes to the live 2nd-gen (Cloud Run-backed) mtnWebhook function,
      // not just the Cloud Run-native https://mtnwebhook-<hash>-uc.a.run.app
      // URL Firebase also assigns it. Confirmed empirically (Firebase docs
      // don't state this explicitly for 2nd gen) — both formats returned an
      // identical 403 body from mtnWebhook's own isAuthorizedWebhookRequest
      // rejection, proving both reach the same deployed function. See
      // PHASE_3C_REPORT.md. Kept this format (rather than switching to the
      // *.run.app URL) because it doesn't embed a deploy-specific hash
      // (the "oh5mmorzca" in mtnwebhook-oh5mmorzca-uc.a.run.app) that isn't
      // derivable from projectID/region alone and could change on
      // redeploy — no Firebase Functions API exposes a function's own live
      // *.run.app URL at runtime to construct it dynamically either.
      const callbackUrl = `https://us-central1-${projectID.value()}.cloudfunctions.net/mtnWebhook?key=${encodeURIComponent(webhookSecret)}`;

      const paymentResponse = await fetch(
        `${baseHost}/collection/v1_0/requesttopay`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "X-Reference-Id": txRef,
            "X-Target-Environment": targetEnv,
            "Ocp-Apim-Subscription-Key": mtnSubKey.value(),
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            amount: amount.toString(),
            currency: "UGX",
            externalId: choirId,
            payer: { partyIdType: "MSISDN", partyId: phone.replace("+256", "256") },
            payerMessage: "KwayaPro Subscription",
            payeeNote: "Monthly subscription payment",
            callbackUrl,
          }),
        },
      );

      if (paymentResponse.status !== 202) {
        const errorBody = await paymentResponse.text();
        logger.error(`MTN payment initiation failed: ${errorBody}`);
        res.status(502).json({error: "Payment initiation failed"});
        return;
      }

      await db.collection("payment_requests").doc(txRef).set({
        choirId, provider: "mtn", amount, phone, status: "pending", createdAt: FieldValue.serverTimestamp(),
      });
      res.json({ success: true, txRef });
    } catch (e) {
      logger.error("MTN payment error", e);
      res.status(502).json({error: "Payment provider error"});
    }
  },
);

// ── Cancel Subscription (Phase 3b) ────────────────────────────────
// Pro -> Free downgrade. Same auth pattern as initiatePayment (verified ID
// token), plus a server-side leader/director role check — not just "any
// member", matching member_detail_screen.dart's own leader/director-only
// permission-management gate. The client never writes subscriptions/choirs
// plan fields directly; firestore.rules already blocks that
// (`subscriptions` is `allow write: if false`, and while `choirs` update
// technically allows leader/director client writes, routing this through a
// Cloud Function keeps a single, auditable trust boundary for every plan
// change rather than splitting it across two enforcement paths).
//
// Immediate effect, not "at period end" — see PHASE_3B_REPORT.md Fix B for
// the full reasoning: initiatePayment only ever performs a one-time MTN
// requesttopay charge, not a recurring subscription, and nothing in this
// codebase (no scheduled function, no provider-side mechanism) tracks or
// enforces a "current paid period" against subscriptions.endDate today —
// that field is written but never read back by anything. There is no
// coherent period to downgrade "at the end of," so downgrade takes effect
// now.
export const cancelSubscription = onRequest(
  { cors: true },
  async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({error: "You must be signed in to do this."});
      return;
    }

    let uid: string;
    try {
      const idToken = authHeader.slice("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (e) {
      logger.warn("cancelSubscription: invalid ID token", e);
      res.status(401).json({error: "Your session has expired. Please sign in again."});
      return;
    }

    const { choirId } = req.body as { choirId?: string };
    if (!choirId || typeof choirId !== "string") {
      res.status(400).json({error: "Missing choirId"});
      return;
    }

    const membershipSnap = await db.collection("choir_memberships").doc(`${choirId}_${uid}`).get();
    const role = membershipSnap.data()?.role;
    if (role !== "leader" && role !== "director") {
      res.status(403).json({error: "Only a choir leader or director can change the subscription plan."});
      return;
    }

    const subRef = db.collection("subscriptions").doc(choirId);
    const subSnap = await subRef.get();
    if (!subSnap.exists || subSnap.data()?.status !== "active") {
      res.status(409).json({error: "This choir doesn't have an active Pro subscription to cancel."});
      return;
    }

    await subRef.update({ status: "cancelled" });
    await db.collection("choirs").doc(choirId).update({ plan: "free" });

    logger.info(`Subscription cancelled: choir=${choirId} by user=${uid}`);
    res.json({ success: true, choirId });
  },
);

// ── MTN Webhook ─────────────────────────────────────────────────
export const mtnWebhook = onRequest(
  { cors: true, secrets: [mtnWebhookSec] },
  async (req, res) => {
    if (!isAuthorizedWebhookRequest(req, mtnWebhookSec.value())) {
      logger.warn("mtnWebhook: rejected — missing or invalid webhook credentials");
      res.status(403).json({error: "Invalid or missing webhook credentials"});
      return;
    }

    const { referenceId, status } = req.body;
    if (!referenceId || !status) {
      res.status(400).json({error: "Missing referenceId or status"}); return;
    }

    const paymentRef = await db.collection("payment_requests").doc(referenceId).get();
    if (!paymentRef.exists) {
      res.status(404).json({error: "Payment request not found"}); return;
    }

    const data = paymentRef.data()!;

    // Idempotency: MTN (like most payment providers) may retry a callback on
    // timeout or a missing ack. A replayed callback must not re-extend the
    // subscription or reprocess an already-completed request.
    if (data.status === "completed") {
      logger.info(`mtnWebhook: ${referenceId} already completed, ignoring replay`);
      res.status(200).json({ success: true, alreadyProcessed: true });
      return;
    }

    const choirId = data.choirId as string;
    if (!choirId) {
      res.status(500).json({error: "Payment request is missing its choirId"});
      return;
    }

    if (status === "SUCCESSFUL") {
      const now = new Date();
      const endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      await db.collection("subscriptions").doc(choirId).set({
        plan: "pro",
        provider: "mtn",
        startDate: Timestamp.fromDate(now),
        endDate: Timestamp.fromDate(endDate),
        txRef: referenceId,
        status: "active",
      }, { merge: true });

      await db.collection("choirs").doc(choirId).update({ plan: "pro" });
      await paymentRef.ref.update({ status: "completed" });
      logger.info(`MTN payment completed: ${referenceId}`);
    } else {
      await paymentRef.ref.update({ status: "failed" });
      logger.warn(`MTN payment failed: ${referenceId}`);
    }

    res.status(200).json({ success: true });
  },
);

// ── Guest Director Join (Phase 2b) ───────────────────────────────
// Replaces the old client-side flow (RehearsalRepository.validateGuestToken +
// getSessionByToken + ChoirRepository.addGuestDirector), which self-created a
// choir_memberships doc with role: 'director' directly from the client. That
// write is now correctly blocked by firestore.rules (see PHASE_2_REPORT.md
// §1) — self-elevation to 'director' can never be permitted from client-side
// rules without reopening the vulnerability the rules were changed to close,
// because a ChoirMembership document carries no reference back to the
// rehearsal session/token that would justify it. Doing the grant here, with
// the Admin SDK (which bypasses security rules), is the architecturally
// correct place for it — and lets us enforce guestTokenExpiry server-side,
// at the moment of grant, which resolves the original audit's "guest
// director token expiry is only checked by a 30-minute scheduled cleanup"
// finding for real.
export const joinAsGuestDirector = onRequest(
  { cors: true },
  async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ error: "You must be signed in to accept this invite." });
      return;
    }

    let uid: string;
    try {
      const idToken = authHeader.slice("Bearer ".length);
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (e) {
      logger.warn("joinAsGuestDirector: invalid ID token", e);
      res.status(401).json({ error: "Your session has expired. Please sign in again." });
      return;
    }

    const { token } = req.body as { token?: string };
    if (!token || typeof token !== "string") {
      res.status(400).json({ error: "Missing invite token." });
      return;
    }

    // Same lookup RehearsalRepository.validateGuestToken/getSessionByToken
    // used to perform client-side — ported here rather than duplicated, this
    // is now the single source of truth for guest-token validation.
    const sessionQuery = await db.collection("rehearsal_sessions")
      .where("guestToken", "==", token)
      .limit(1)
      .get();

    if (sessionQuery.empty) {
      res.status(404).json({ error: "This invite link is invalid or has already been used." });
      return;
    }

    const sessionDoc = sessionQuery.docs[0];
    const session = sessionDoc.data();

    const expiryTimestamp = session.guestTokenExpiry as Timestamp | undefined;
    if (!session.isGuestDirector || !expiryTimestamp) {
      res.status(410).json({ error: "This invite link has been revoked." });
      return;
    }
    if (new Date() >= expiryTimestamp.toDate()) {
      res.status(410).json({ error: "This invite link has expired." });
      return;
    }

    const choirId = session.choirId as string;
    if (!choirId) {
      res.status(500).json({ error: "This rehearsal session is missing its choir." });
      return;
    }

    const membershipRef = db.collection("choir_memberships").doc(`${choirId}_${uid}`);
    const existingSnap = await membershipRef.get();
    const existingData = existingSnap.data();

    // Don't clobber an existing leader/director's own membership with a
    // guest grant — they already have full access.
    if (existingData?.role === "leader" || existingData?.role === "director") {
      res.json({ success: true, choirId, sessionId: sessionDoc.id, alreadyMember: true });
      return;
    }

    // Real display name, denormalized onto the membership doc (Phase 2b Fix
    // 2) rather than a generic placeholder — Admin SDK reads bypass rules,
    // so this cross-user users/{uid} read is fine here even though the
    // client can no longer do the equivalent read itself.
    const userDoc = await db.collection("users").doc(uid).get();
    const displayName = (userDoc.data()?.name as string | undefined)?.trim() || "Guest Director";

    // SECURITY FIX (Leader/Director audit): this grant used to be
    // choir-wide and permanent — role: "director" is checked by
    // hasAnyRole(choirId, ['leader','director']) everywhere in
    // firestore.rules, with nothing anywhere tying it back to
    // directorSessionId, and checkGuestTokenExpiry only ever cleared the
    // session doc's own guestToken fields, never this membership. Confirmed
    // live via the Firebase emulator: a guest could touch a different
    // session, edit the choir profile, and retained full director rights
    // indefinitely after their session's "expiry". Fixed by (1) recording
    // directorPriorRole/directorPriorPermissions so expiry can restore
    // exactly what was there before, and (2) directorSessionId, which
    // firestore.rules now requires to match the specific resource being
    // acted on for session-scoped actions (rehearsal_sessions, attendance)
    // instead of granting all director rights choir-wide.
    await membershipRef.set({
      choirId,
      userId: uid,
      name: displayName,
      role: "director",
      defaultVoicePart: existingData?.defaultVoicePart ?? "S",
      permissions: existingData?.permissions ?? [],
      joinedAt: existingData?.joinedAt ?? FieldValue.serverTimestamp(),
      directorSessionId: sessionDoc.id,
      directorPriorRole: existingData?.directorPriorRole ?? existingData?.role ?? "chorister",
      directorPriorPermissions: existingData?.directorPriorPermissions ?? existingData?.permissions ?? [],
    }, { merge: true });

    // Single-use: consume the token immediately so it can't be replayed by a
    // second person (or reused after the fact). The prior client-side flow
    // never invalidated the token after use — anyone with the link could
    // join repeatedly, by design or not, until the 30-minute scheduled
    // cleanup or a manual revoke. This closes that gap.
    //
    // (Phase 3 note: every FieldValue/Timestamp usage in this file was
    // migrated to this modular firebase-admin/firestore import — see
    // PHASE_3_REPORT.md Fix 0b for why: the admin.firestore.FieldValue/
    // .Timestamp namespace reproducibly threw "Cannot read properties of
    // undefined" inside the actual Functions Emulator, most likely because
    // functions/package.json declared an unsupported Node 24 runtime — now
    // fixed to Node 20. The modular import is used everywhere regardless,
    // as defense in depth.)
    await sessionDoc.ref.update({
      guestToken: FieldValue.delete(),
      guestTokenExpiry: FieldValue.delete(),
    });

    logger.info(`Guest director granted: choir=${choirId} session=${sessionDoc.id} user=${uid}`);
    res.json({
      success: true,
      choirId,
      sessionId: sessionDoc.id,
      title: session.title ?? null,
    });
  },
);

// ── Invite-code lookup + uniqueness check (server-side, same rationale as
// joinAsGuestDirector above) ──────────────────────────────────────────────
// choir_repository.dart's getChoirByInviteCode/generateUniqueInviteCode used
// to run `where('inviteCode', isEqualTo: ...)` queries directly against
// Firestore. Firestore security rules can only authorize a query when the
// rule is expressible purely in terms of resource.data + request.auth — they
// cannot check "the caller already knows this specific code", so the only
// rule that made those queries succeed was `allow read: if isAuthenticated()`,
// which really means "any signed-in user can list the entire choirs
// collection", dumping every choir's invite code, not just the one being
// looked up. That defeats the entire "you need the code" model. Moving the
// lookup here (Admin SDK bypasses rules) lets the rule stay
// isTenantMember(choirId)-only while still letting new, non-member users
// resolve a code they were actually given.
function verifyBearerAuth(req: {headers: {authorization?: string}}): Promise<string> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    return Promise.reject(new Error("unauthenticated"));
  }
  return admin.auth().verifyIdToken(authHeader.slice("Bearer ".length)).then((d) => d.uid);
}

// ── Per-UID rate limiting (Firestore-backed fixed window) ─────────────────
// Raised on review: these two endpoints require *a* signed-in account, not
// tenant membership — trivial to obtain (a throwaway email/password sign-up
// costs nothing) — and there's no Firebase App Check configured anywhere in
// this project (no app_check client package, no enforceAppCheck option) to
// raise that bar. Invite codes are 32^6 (~1.07B) combinations — not
// astronomical, and the realistic threat here isn't "guess one specific
// code" but "script a scan and log every 200 vs 404 to harvest every real
// choir's code", which only requires hitting *some* valid codes, not the
// one you're after. This fixed-window counter is a cheap stopgap that costs
// legitimate use nothing (a handful of calls per minute) while making a
// scripted scan impractically slow. App Check would be the more complete
// fix if this surface ever sees real abuse.
const RATE_LIMIT_WINDOW_MS = 60_000;

async function checkRateLimit(uid: string, key: string, maxPerWindow: number): Promise<boolean> {
  const ref = db.collection("_rate_limits").doc(`${key}_${uid}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() as { count?: number; windowStart?: number } | undefined;
    const now = Date.now();
    if (!data || now - (data.windowStart ?? 0) > RATE_LIMIT_WINDOW_MS) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }
    if ((data.count ?? 0) >= maxPerWindow) {
      return false;
    }
    tx.update(ref, { count: FieldValue.increment(1) });
    return true;
  });
}

export const lookupChoirByInviteCode = onRequest(
  { cors: true },
  async (req, res) => {
    let uid: string;
    try {
      uid = await verifyBearerAuth(req);
    } catch {
      res.status(401).json({ error: "You must be signed in." });
      return;
    }

    // 10/min — generous for real typos while joining, far too slow to
    // script a meaningful scan of the invite-code keyspace.
    if (!(await checkRateLimit(uid, "lookupChoirByInviteCode", 10))) {
      res.status(429).json({ error: "Too many attempts. Please wait a minute and try again." });
      return;
    }

    const code = (req.body as { code?: string })?.code;
    if (!code || typeof code !== "string") {
      res.status(400).json({ error: "Missing invite code." });
      return;
    }

    const query = await db.collection("choirs")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();

    if (query.empty) {
      res.status(404).json({ error: "Invalid invite code." });
      return;
    }

    const choir = query.docs[0].data();
    // Minimal response — deliberately omits leaderId, plan, songCount, and
    // the inviteCode itself, none of which the join UI needs.
    res.json({
      choirId: query.docs[0].id,
      name: choir.name ?? "",
      churchName: choir.churchName ?? "",
    });
  },
);

export const checkInviteCodeAvailable = onRequest(
  { cors: true },
  async (req, res) => {
    let uid: string;
    try {
      uid = await verifyBearerAuth(req);
    } catch {
      res.status(401).json({ error: "You must be signed in." });
      return;
    }

    // 20/min — generateUniqueInviteCode() retries up to 5x per choir
    // created, so this comfortably covers a leader creating several choirs
    // in a session while still capping scripted abuse.
    if (!(await checkRateLimit(uid, "checkInviteCodeAvailable", 20))) {
      res.status(429).json({ error: "Too many attempts. Please wait a minute and try again." });
      return;
    }

    const code = (req.body as { code?: string })?.code;
    if (!code || typeof code !== "string") {
      res.status(400).json({ error: "Missing invite code." });
      return;
    }

    const query = await db.collection("choirs")
      .where("inviteCode", "==", code)
      .limit(1)
      .get();

    res.json({ available: query.empty });
  },
);

// FUNCTIONAL FIX (Leader/Director on-device audit, task #29): there was no
// way for a Leader to permanently assign/revoke the 'director' role at
// all — firestore.rules' update rule for choir_memberships intentionally
// makes `role` immutable client-side (see Finding #3 comment above that
// rule), so this must go through the Admin SDK like the guest-director
// grant does. Unlike guest-director sessions (time-limited, tied to a
// rehearsal session/token), this is a permanent role change the Leader
// makes directly from Members & Roles — only chorister<->director
// transitions are allowed; 'leader' can never be granted or removed here.
export const assignMemberRole = onRequest(
  { cors: true },
  async (req, res) => {
    let uid: string;
    try {
      uid = await verifyBearerAuth(req);
    } catch {
      res.status(401).json({ error: "You must be signed in." });
      return;
    }

    if (!(await checkRateLimit(uid, "assignMemberRole", 20))) {
      res.status(429).json({ error: "Too many attempts. Please wait a minute and try again." });
      return;
    }

    const { choirId, targetUserId, role } = req.body as {
      choirId?: string;
      targetUserId?: string;
      role?: string;
    };
    if (!choirId || !targetUserId || (role !== "director" && role !== "chorister")) {
      res.status(400).json({ error: "Missing or invalid choirId/targetUserId/role." });
      return;
    }

    const callerSnap = await db.collection("choir_memberships").doc(`${choirId}_${uid}`).get();
    if (callerSnap.data()?.role !== "leader") {
      res.status(403).json({ error: "Only the choir leader can change member roles." });
      return;
    }

    if (targetUserId === uid) {
      res.status(400).json({ error: "You cannot change your own role." });
      return;
    }

    const targetRef = db.collection("choir_memberships").doc(`${choirId}_${targetUserId}`);
    const targetSnap = await targetRef.get();
    if (!targetSnap.exists) {
      res.status(404).json({ error: "Member not found." });
      return;
    }
    const currentRole = targetSnap.data()?.role;
    if (currentRole === "leader") {
      res.status(400).json({ error: "The choir leader's role cannot be changed here." });
      return;
    }
    if (currentRole !== "director" && currentRole !== "chorister") {
      res.status(400).json({ error: "Member is not eligible for this role change." });
      return;
    }

    await targetRef.update({ role });
    logger.info(`Role change: choir=${choirId} target=${targetUserId} -> ${role} by leader=${uid}`);
    res.json({ success: true });
  },
);

// ── Propagate display-name changes onto choir_memberships (Phase 2b Fix 2) ──
// Denormalizing name onto choir_memberships (see joinChoir, onboarding_screen
// choir creation, and joinAsGuestDirector above) means membership docs no
// longer track a user's later name changes automatically. This trigger keeps
// them in sync going forward. It does NOT backfill existing membership docs
// that still hold the old 'Member'/'Leader' placeholders — see
// functions/scripts/backfill-membership-names.js for a one-time fix for
// those, which needs to be run once by whoever holds project credentials.
export const onUserProfileUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;
  if (before?.name === after.name) return;

  const userId = event.params.userId;
  const memberships = await db.collection("choir_memberships").where("userId", "==", userId).get();
  if (memberships.empty) return;

  const batch = db.batch();
  memberships.docs.forEach((doc) => {
    batch.update(doc.ref, { name: after.name });
  });
  await batch.commit();
  logger.info(`Propagated name change for user ${userId} to ${memberships.size} membership(s)`);
});

// [REDACTED FROM HISTORY: unauthenticated password-reset debug endpoint]

// [REDACTED FROM HISTORY: unauthenticated invite-code-leak debug endpoint]

// -- Airtel Webhook disabled --
