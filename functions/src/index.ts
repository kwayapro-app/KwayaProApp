import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
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
const airtelClientId = defineSecret("AIRTEL_CLIENT_ID");
const airtelClientSec = defineSecret("AIRTEL_CLIENT_SECRET");
const airtelWebhookSec = defineSecret("AIRTEL_WEBHOOK_SECRET");
const r2AccountId    = defineSecret("R2_ACCOUNT_ID");
const r2AccessKey    = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretKey    = defineSecret("R2_SECRET_ACCESS_KEY");
const r2BucketName   = defineSecret("R2_BUCKET_NAME");

// ── R2 Presigned URL Generation ─────────────────────────────────
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
export const rehearsalReminder = onSchedule("0 * * * *", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const tomorrow = new Date(now.toDate().getTime() + 24 * 60 * 60 * 1000);
  const endWindow = new Date(tomorrow.getTime() + 60 * 60 * 1000);

  const sessions = await db.collection("rehearsal_sessions")
    .where("date", ">=", admin.firestore.Timestamp.fromDate(tomorrow))
    .where("date", "<=", admin.firestore.Timestamp.fromDate(endWindow))
    .get();

  for (const doc of sessions.docs) {
    const session = doc.data();
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
        notification: { title: "Rehearsal Tomorrow!", body: `Don't forget: ${session.date} at ${session.time}` },
        data: { type: "rehearsal_reminder", sessionId: doc.id, choirId },
        tokens,
      };
      try { await admin.messaging().sendEachForMulticast(message); }
      catch (e) { logger.warn("FCM reminder failed", e); }
    }
  }
});

// ── Guest Token Expiry ──────────────────────────────────────────
export const checkGuestTokenExpiry = onSchedule("*/30 * * * *", async () => {
  const now = admin.firestore.Timestamp.now();
  const sessions = await db.collection("rehearsal_sessions")
    .where("guestTokenExpiry", "<=", now)
    .where("isGuestDirector", "==", true)
    .get();

  for (const doc of sessions.docs) {
    await doc.ref.update({
      guestToken: admin.firestore.FieldValue.delete(),
      guestTokenExpiry: admin.firestore.FieldValue.delete(),
      isGuestDirector: false,
    });
    logger.info(`Expired guest token for session ${doc.id}`);
  }
});

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

// ── Payment Webhook ─────────────────────────────────────────────
export const paymentWebhook = onRequest(
  { cors: true, secrets: [mtnWebhookSec, airtelWebhookSec] },
  async (req, res) => {
    const { txRef, status, provider, choirId } = req.body;

    if (!txRef || !status) {
      res.status(400).json({error: "Missing txRef or status"}); return;
    }

    // Validate webhook signature if present
    const signature = req.headers["x-webhook-signature"] as string | undefined;
    if (signature) {
      const mtnSecret = mtnWebhookSec.value();
      const airtelSecret = airtelWebhookSec.value();
      const expected = provider === "airtel" ? airtelSecret : mtnSecret;
      if (expected && signature !== expected) {
        res.status(403).json({error: "Invalid signature"}); return;
      }
    }

    if (status === "completed") {
      const now = new Date();
      const endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      await db.collection("subscriptions").doc(choirId || "unknown").set({
        plan: "pro",
        provider: provider || "mtn",
        startDate: admin.firestore.Timestamp.fromDate(now),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
        txRef,
        status: "active",
      }, { merge: true });

      if (choirId) {
        await db.collection("choirs").doc(choirId).update({ plan: "pro" });
      }

      logger.info(`Payment completed: ${txRef}`);
      res.json({ success: true });
    } else {
      logger.warn(`Payment failed: ${txRef}`);
      res.json({ success: false, reason: "payment_failed" });
    }
  },
);

// ── Initiate Payment (Callable) ─────────────────────────────────
export const initiatePayment = onRequest(
  { cors: true, secrets: [mtnApiUser, mtnApiKey, mtnSubKey, mtnTargetEnv, airtelClientId, airtelClientSec] },
  async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) { res.status(401).json({error: "Unauthorized"}); return; }

    const { provider, phone, amount, choirId } = req.body;
    if (!provider || !phone || !amount || !choirId) {
      res.status(400).json({error: "Missing required fields"}); return;
    }

    const txRef = `TXN-${choirId}-${Date.now()}`;

    if (provider === "mtn") {
      try {
        const tokenResponse = await fetch(
          "https://sandbox.momodeveloper.mtn.com/collection/token/",
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
          res.status(502).json({error: "Failed to get MTN token"}); return;
        }

        const callbackUrl = `https://us-central1-kwayapro-production.cloudfunctions.net/mtnWebhook`;
        const paymentResponse = await fetch(
          `https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "X-Reference-Id": txRef,
              "X-Target-Environment": mtnTargetEnv.value() || "sandbox",
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

        if (paymentResponse.status === 202) {
          await db.collection("payment_requests").doc(txRef).set({
            choirId, provider: "mtn", amount, phone, status: "pending", createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          res.json({ success: true, txRef });
        } else {
          const errorBody = await paymentResponse.text();
          logger.error(`MTN payment initiation failed: ${errorBody}`);
          res.status(502).json({error: "Payment initiation failed"});
        }
      } catch (e) {
        logger.error("MTN payment error", e);
        res.status(502).json({error: "Payment provider error"});
      }
    } else if (provider === "airtel") {
      try {
        const authResponse = await fetch(
          "https://openapi.airtel.africa/auth/oauth2/token",
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              client_id: airtelClientId.value(),
              client_secret: airtelClientSec.value(),
              grant_type: "client_credentials",
            }),
          },
        );
        const authData = await authResponse.json() as { access_token?: string };
        const accessToken = authData.access_token;
        if (!accessToken) {
          res.status(502).json({error: "Failed to get Airtel token"}); return;
        }

        const callbackUrl = `https://us-central1-kwayapro-production.cloudfunctions.net/airtelWebhook`;
        const paymentResponse = await fetch(
          "https://openapi.airtel.africa/merchant/v1/payments/",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "X-Country": "UG",
              "X-Currency": "UGX",
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              reference: txRef,
              subscriber: { country: "UG", currency: "UGX", msisdn: phone },
              transaction: { amount: amount.toString(), country: "UG", currency: "UGX", id: txRef },
              callbackUrl,
            }),
          },
        );

        if (paymentResponse.status === 200 || paymentResponse.status === 201) {
          await db.collection("payment_requests").doc(txRef).set({
            choirId, provider: "airtel", amount, phone, status: "pending", createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          res.json({ success: true, txRef });
        } else {
          const errorBody = await paymentResponse.text();
          logger.error(`Airtel payment initiation failed: ${errorBody}`);
          res.status(502).json({error: "Payment initiation failed"});
        }
      } catch (e) {
        logger.error("Airtel payment error", e);
        res.status(502).json({error: "Payment provider error"});
      }
    } else {
      res.status(400).json({error: "Unsupported provider"});
    }
  },
);

// ── MTN Webhook ─────────────────────────────────────────────────
export const mtnWebhook = onRequest(
  { cors: true, secrets: [mtnWebhookSec] },
  async (req, res) => {
    const signature = req.headers["x-webhook-signature"] as string | undefined;
    const expected = mtnWebhookSec.value();
    if (expected && signature !== expected) {
      res.status(403).json({error: "Invalid signature"}); return;
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
    const choirId = data.choirId as string;

    if (status === "SUCCESSFUL") {
      const now = new Date();
      const endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      await db.collection("subscriptions").doc(choirId).set({
        plan: "pro",
        provider: "mtn",
        startDate: admin.firestore.Timestamp.fromDate(now),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
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

// ── Airtel Webhook ──────────────────────────────────────────────
export const airtelWebhook = onRequest(
  { cors: true, secrets: [airtelWebhookSec] },
  async (req, res) => {
    const signature = req.headers["x-webhook-signature"] as string | undefined;
    const expected = airtelWebhookSec.value();
    if (expected && signature !== expected) {
      res.status(403).json({error: "Invalid signature"}); return;
    }

    const { transaction: { id: referenceId } = {}, status_code: statusCode } = req.body;
    if (!referenceId) {
      res.status(400).json({error: "Missing transaction id"}); return;
    }

    const paymentRef = await db.collection("payment_requests").doc(referenceId).get();
    if (!paymentRef.exists) {
      res.status(404).json({error: "Payment request not found"}); return;
    }

    const data = paymentRef.data()!;
    const choirId = data.choirId as string;

    if (statusCode === "200" || statusCode === "TS" || statusCode === "SUCCESS") {
      const now = new Date();
      const endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

      await db.collection("subscriptions").doc(choirId).set({
        plan: "pro",
        provider: "airtel",
        startDate: admin.firestore.Timestamp.fromDate(now),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
        txRef: referenceId,
        status: "active",
      }, { merge: true });

      await db.collection("choirs").doc(choirId).update({ plan: "pro" });
      await paymentRef.ref.update({ status: "completed" });
      logger.info(`Airtel payment completed: ${referenceId}`);
    } else {
      await paymentRef.ref.update({ status: "failed" });
      logger.warn(`Airtel payment failed: ${referenceId}`);
    }

    res.status(200).json({ success: true });
  },
);
