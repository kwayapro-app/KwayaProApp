// Phase 7 test-coverage backfill: committed integration test suite for the
// Cloud Functions with the highest risk (payments, subscription state,
// guest-director auth) and, until now, ZERO persisted test coverage — every
// prior phase (2b, 3, 3b, 6) exercised these functions against the real
// Functions + Auth + Firestore emulators, but only from ephemeral
// session-scratchpad scripts that were never committed to the repo. This
// file consolidates and commits that coverage so it survives for future
// regressions. See PHASE_7_REPORT.md.
//
// Run via (from the repo root, with functions/.secret.local providing a
// test MTN_WEBHOOK_SECRET value — see functions/test/README.md):
//   firebase emulators:exec --config firebase.test.json \
//     --project=kwayapro-app "node functions/test/integration.js"
//
// Scope, stated explicitly rather than overclaimed: initiatePayment's
// actual outbound call to MTN's Collections API (token exchange +
// requesttopay) is NOT exercised here — that requires live MTN sandbox
// credentials and network access this environment doesn't have (see
// PHASE_3_REPORT.md's doc-verification appendix). What IS covered end to
// end: every auth/validation/authorization check initiatePayment performs
// BEFORE that outbound call (unauthenticated, bad token, non-member,
// Airtel-rejected), and mtnWebhook's full logic (it never calls out to MTN
// itself — it only receives a callback), including the real state
// transition to Pro and idempotency on replay.

const admin = require("firebase-admin");

const PROJECT_ID = "kwayapro-app";
const REGION = "us-central1";
const FUNCTIONS_PORT = 5501;
const AUTH_PORT = 9199;
const fnUrl = (name) => `http://127.0.0.1:${FUNCTIONS_PORT}/${PROJECT_ID}/${REGION}/${name}`;
const AUTH_SIGNUP_URL = `http://127.0.0.1:${AUTH_PORT}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

let passed = 0;
let failed = 0;

function check(label, cond, extra) {
  if (cond) {
    console.log(`  ✔ ${label}`);
    passed++;
  } else {
    console.log(`  ✖ ${label}${extra ? " -- " + JSON.stringify(extra) : ""}`);
    failed++;
  }
}

async function signUpTestUser(email) {
  const res = await fetch(AUTH_SIGNUP_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: "testpass123", returnSecureToken: true }),
  });
  const body = await res.json();
  if (!body.idToken) throw new Error("Auth emulator signup failed: " + JSON.stringify(body));
  return { uid: body.localId, idToken: body.idToken };
}

async function seedMembership(choirId, uid, role, extra) {
  await db.collection("choir_memberships").doc(`${choirId}_${uid}`).set({
    choirId, userId: uid, role, defaultVoicePart: "S", permissions: [], joinedAt: new Date(), ...extra,
  });
}

// ---------------------------------------------------------------------
async function testGuestJoin() {
  console.log("\n=== joinAsGuestDirector ===");

  const choirId = "testChoir1";
  await db.collection("choirs").doc(choirId).set({
    choirId, name: "Test Choir", churchName: "Test Church", leaderId: "leader-uid",
    inviteCode: "TST123", plan: "free", songCount: 0, createdAt: new Date(),
  });

  const validSessionId = "session-valid";
  await db.collection("rehearsal_sessions").doc(validSessionId).set({
    sessionId: validSessionId, choirId, title: "Sunday Rehearsal",
    date: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)),
    time: "18:00", location: "Main Hall", directorId: "leader-uid",
    isGuestDirector: true,
    guestToken: "valid-token-123",
    guestTokenExpiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3600000)),
  });

  const expiredSessionId = "session-expired";
  await db.collection("rehearsal_sessions").doc(expiredSessionId).set({
    sessionId: expiredSessionId, choirId, title: "Last Week Rehearsal",
    date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)),
    time: "18:00", location: "Main Hall", directorId: "leader-uid",
    isGuestDirector: true,
    guestToken: "expired-token-456",
    guestTokenExpiry: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)),
  });

  const guest = await signUpTestUser("guest1@test.com");
  await db.collection("users").doc(guest.uid).set({
    userId: guest.uid, name: "Grace Nakato", phone: "+256700111222", createdAt: new Date(),
  });

  {
    const res = await fetch(fnUrl("joinAsGuestDirector"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: "valid-token-123" }),
    });
    check("returns 401 with no Authorization header", res.status === 401, { status: res.status });
  }

  {
    const res = await fetch(fnUrl("joinAsGuestDirector"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${guest.idToken}` },
      body: JSON.stringify({ token: "expired-token-456" }),
    });
    const body = await res.json();
    check("returns 410 for an expired token", res.status === 410, { status: res.status, body });
  }

  {
    const res = await fetch(fnUrl("joinAsGuestDirector"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${guest.idToken}` },
      body: JSON.stringify({ token: "valid-token-123" }),
    });
    const body = await res.json();
    check("returns 200 for a valid token", res.status === 200, { status: res.status, body });
    check("response choirId matches", body.choirId === choirId, body);
    check("response sessionId matches", body.sessionId === validSessionId, body);

    const membershipSnap = await db.collection("choir_memberships").doc(`${choirId}_${guest.uid}`).get();
    check("membership document was created", membershipSnap.exists);
    const m = membershipSnap.data() || {};
    check("role is director", m.role === "director", m);
    check("name is the REAL display name, not a placeholder", m.name === "Grace Nakato", m);

    const sessionSnap = await db.collection("rehearsal_sessions").doc(validSessionId).get();
    const s = sessionSnap.data() || {};
    check("guestToken was deleted from the session after use (single-use)", s.guestToken === undefined, s);
  }

  {
    const res = await fetch(fnUrl("joinAsGuestDirector"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${guest.idToken}` },
      body: JSON.stringify({ token: "valid-token-123" }),
    });
    const body = await res.json();
    check("returns 404 on replay of a consumed token", res.status === 404, { status: res.status, body });
  }
}

// ---------------------------------------------------------------------
async function testInitiatePaymentValidation() {
  console.log("\n=== initiatePayment (pre-MTN-call validation only, see file header) ===");

  const choirId = "payChoir1";
  await db.collection("choirs").doc(choirId).set({
    choirId, name: "Pay Choir", churchName: "Test Church", leaderId: "leader-uid",
    inviteCode: "PAY123", plan: "free", songCount: 0, createdAt: new Date(),
  });

  const member = await signUpTestUser("payer1@test.com");
  await seedMembership(choirId, member.uid, "director");

  const nonMember = await signUpTestUser("outsider1@test.com");

  {
    const res = await fetch(fnUrl("initiatePayment"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ provider: "mtn", phone: "+256700000001", amount: 40000, choirId }),
    });
    check("rejects unauthenticated requests (401)", res.status === 401, { status: res.status });
  }

  {
    const res = await fetch(fnUrl("initiatePayment"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${nonMember.idToken}` },
      body: JSON.stringify({ provider: "mtn", phone: "+256700000001", amount: 40000, choirId }),
    });
    check("rejects a non-member of the choir (403)", res.status === 403, { status: res.status });
  }

  {
    const res = await fetch(fnUrl("initiatePayment"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${member.idToken}` },
      body: JSON.stringify({ provider: "airtel", phone: "+256700000001", amount: 40000, choirId }),
    });
    const body = await res.json();
    check("rejects Airtel cleanly (400, plain-English message, no double-response crash)",
      res.status === 400 && typeof body.error === "string" && !body.error.includes("Exception"),
      { status: res.status, body });
  }

  {
    const res = await fetch(fnUrl("initiatePayment"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${member.idToken}` },
      body: JSON.stringify({ provider: "mtn", choirId }), // missing phone/amount
    });
    check("rejects a request missing required fields (400)", res.status === 400, { status: res.status });
  }
}

// ---------------------------------------------------------------------
async function testMtnWebhook(webhookSecret) {
  console.log("\n=== mtnWebhook (fail-closed auth, idempotency, full state transition) ===");

  const choirId = "webhookChoir1";
  await db.collection("choirs").doc(choirId).set({
    choirId, name: "Webhook Choir", churchName: "Test Church", leaderId: "leader-uid",
    inviteCode: "WHK123", plan: "free", songCount: 0, createdAt: new Date(),
  });

  const refId = "TXN-webhookChoir1-1";
  await db.collection("payment_requests").doc(refId).set({
    choirId, provider: "mtn", amount: 40000, phone: "+256700000009", status: "pending", createdAt: new Date(),
  });

  {
    const res = await fetch(fnUrl("mtnWebhook"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ referenceId: refId, status: "SUCCESSFUL" }),
    });
    check("rejects requests with no key (403, fail-closed)", res.status === 403, { status: res.status });
  }

  {
    const res = await fetch(`${fnUrl("mtnWebhook")}?key=wrong-key`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ referenceId: refId, status: "SUCCESSFUL" }),
    });
    check("rejects requests with a wrong key (403, fail-closed)", res.status === 403, { status: res.status });
  }

  {
    const res = await fetch(`${fnUrl("mtnWebhook")}?key=${encodeURIComponent(webhookSecret)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ referenceId: refId, status: "SUCCESSFUL" }),
    });
    check("the correct key succeeds (200)", res.status === 200, { status: res.status });

    const payReq = await db.collection("payment_requests").doc(refId).get();
    check("payment_request marked completed", payReq.data()?.status === "completed", payReq.data());

    const sub = await db.collection("subscriptions").doc(choirId).get();
    check("subscriptions/{choirId} created with plan pro / status active",
      sub.data()?.plan === "pro" && sub.data()?.status === "active", sub.data());

    const choir = await db.collection("choirs").doc(choirId).get();
    check("choirs/{choirId}.plan flipped to pro", choir.data()?.plan === "pro", choir.data());
  }

  {
    const beforeSub = await db.collection("subscriptions").doc(choirId).get();
    const beforeEndDate = beforeSub.data()?.endDate;

    const res = await fetch(`${fnUrl("mtnWebhook")}?key=${encodeURIComponent(webhookSecret)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ referenceId: refId, status: "SUCCESSFUL" }),
    });
    const body = await res.json();
    check("replaying the same completed webhook is a no-op (alreadyProcessed: true)",
      res.status === 200 && body.alreadyProcessed === true, body);

    const afterSub = await db.collection("subscriptions").doc(choirId).get();
    check("endDate was NOT re-extended by the replay",
      JSON.stringify(afterSub.data()?.endDate) === JSON.stringify(beforeEndDate));
  }

  // A second, independent payment request to exercise the FAILED branch
  // without disturbing the completed-state assertions above.
  const refId2 = "TXN-webhookChoir1-2";
  await db.collection("payment_requests").doc(refId2).set({
    choirId, provider: "mtn", amount: 40000, phone: "+256700000009", status: "pending", createdAt: new Date(),
  });
  {
    const res = await fetch(`${fnUrl("mtnWebhook")}?key=${encodeURIComponent(webhookSecret)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ referenceId: refId2, status: "FAILED" }),
    });
    check("a FAILED status returns 200 and marks the request failed", res.status === 200, { status: res.status });
    const payReq2 = await db.collection("payment_requests").doc(refId2).get();
    check("payment_request marked failed (not completed)", payReq2.data()?.status === "failed", payReq2.data());
  }
}

// ---------------------------------------------------------------------
async function testCancelSubscription() {
  console.log("\n=== cancelSubscription ===");

  const choirId = "cancelChoir1";
  await db.collection("choirs").doc(choirId).set({
    choirId, name: "Cancel Choir", churchName: "Test Church", leaderId: "leader-uid",
    inviteCode: "CXL123", plan: "pro", songCount: 7, createdAt: new Date(),
  });
  await db.collection("subscriptions").doc(choirId).set({
    plan: "pro", provider: "mtn", startDate: new Date(), endDate: new Date(),
    txRef: "TXN-cancelChoir1-1", status: "active",
  });

  const chorister = await signUpTestUser("chorister-cxl@test.com");
  await seedMembership(choirId, chorister.uid, "chorister");

  const director = await signUpTestUser("director-cxl@test.com");
  await seedMembership(choirId, director.uid, "director");

  {
    const res = await fetch(fnUrl("cancelSubscription"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ choirId }),
    });
    check("rejects unauthenticated requests (401)", res.status === 401, { status: res.status });
  }

  {
    const res = await fetch(fnUrl("cancelSubscription"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${chorister.idToken}` },
      body: JSON.stringify({ choirId }),
    });
    check("a chorister CANNOT downgrade (403)", res.status === 403, { status: res.status });

    const sub = await db.collection("subscriptions").doc(choirId).get();
    check("subscription status left untouched after the rejected attempt",
      sub.data()?.status === "active", sub.data());
  }

  {
    const res = await fetch(fnUrl("cancelSubscription"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${director.idToken}` },
      body: JSON.stringify({ choirId }),
    });
    check("a director CAN downgrade their own choir (200)", res.status === 200, { status: res.status });

    const sub = await db.collection("subscriptions").doc(choirId).get();
    check("subscriptions/{choirId}.status -> cancelled", sub.data()?.status === "cancelled", sub.data());

    const choir = await db.collection("choirs").doc(choirId).get();
    check("choirs/{choirId}.plan -> free", choir.data()?.plan === "free", choir.data());
    check("existing songCount left untouched (existing songs not deleted)", choir.data()?.songCount === 7, choir.data());
  }

  {
    const res = await fetch(fnUrl("cancelSubscription"), {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${director.idToken}` },
      body: JSON.stringify({ choirId }),
    });
    check("downgrading an already-cancelled choir returns 409, not a silent re-success", res.status === 409, { status: res.status });
  }
}

// ---------------------------------------------------------------------
async function testPaymentWebhookRemoved() {
  console.log("\n=== paymentWebhook (Phase 3b removal) ===");
  const res = await fetch(fnUrl("paymentWebhook"), { method: "POST" });
  check("paymentWebhook route returns 404 — confirmed genuinely removed from this build", res.status === 404, { status: res.status });
}

// ---------------------------------------------------------------------
async function main() {
  const webhookSecret = process.env.MTN_WEBHOOK_SECRET_TEST_VALUE;
  if (!webhookSecret) {
    throw new Error(
      "MTN_WEBHOOK_SECRET_TEST_VALUE env var not set. This must match the " +
      "MTN_WEBHOOK_SECRET value the Functions emulator was started with " +
      "(via functions/.secret.local) so the mtnWebhook success path can be " +
      "exercised — see functions/test/README.md."
    );
  }

  await testGuestJoin();
  await testInitiatePaymentValidation();
  await testMtnWebhook(webhookSecret);
  await testCancelSubscription();
  await testPaymentWebhookRemoved();

  console.log(`\n${passed} passing, ${failed} failing`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error("Integration test crashed:", e);
  process.exit(1);
});
