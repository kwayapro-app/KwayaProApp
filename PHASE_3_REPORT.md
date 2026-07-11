# Phase 3 Report — Payment Integrity

**Scope:** `functions/src/index.ts`, `functions/package.json`, `billing_screen.dart` and its supporting `subscription_repository.dart` (same "wiring" interpretation as Phase 2b — the repository is the data layer the screen directly depends on), plus one narrowly-scoped `firestore.rules` change (Fix 5, called out explicitly below). **Not deployed.**

---

## Fix 0 — mtnWebhook callback URL project ID

**Was this URL ever functional?** No evidence it was. `initiatePayment`'s `callbackUrl` was already corrected to `kwayapro-app` in a prior manual fix (confirmed present before this phase started). Searched the repo for any external registration of this URL — no config file, README, or script references a callback URL needing registration in an MTN/Airtel merchant portal. Per how the code calls MTN's `requesttopay` endpoint, `callbackUrl` is sent fresh as a field in the request body on every single payment initiation — it is not a portal-side static config. **Fixing/changing this URL requires no external MTN/Airtel dashboard update.**

**Changed anyway, from hardcoded to derived:** replaced the hardcoded project ID with `firebase-functions/params`'s built-in `projectID` parameter (`import { projectID } from "firebase-functions/params"`, then `projectID.value()`), per current Firebase docs — this is the officially documented current pattern for a function to know its own project ID without a literal string (confirmed via `firebase.google.com/docs/functions/config-env`: `projectID` is a built-in parameter, "the Cloud project in which the function is running"). No Cloud Functions mechanism exists to derive a function's own *full URL* automatically (confirmed via the same doc and `docs.cloud.google.com/functions/docs/configuring/env-var` — no `GCLOUD_PROJECT`-style env var is documented for 2nd-gen functions), so the URL is still assembled from a template string, just with the project ID no longer hardcoded: `` `https://us-central1-${projectID.value()}.cloudfunctions.net/mtnWebhook` ``.

---

## Fix 0b — `FieldValue`/`Timestamp` emulator crash

**Reproduced in isolation, and found the likely root cause.** `functions/package.json` declared `"engines": { "node": "24" }`. Checked current Firebase docs (`firebase.google.com/docs/functions/manage-functions?gen=2nd`): **Cloud Functions 2nd gen only supports Node.js 22, 20, and 18 (deprecated) — Node 24 is not a supported runtime at all.** The local Functions Emulator log even says so implicitly: `functions: Using node@24 from host` (before this fix) — it silently ran under whatever Node is installed on the machine rather than a supported version, since 24 isn't one Firebase recognizes.

I could not fully confirm the exact mechanism (only Node 24 is installed in this environment, no version manager available, so I couldn't A/B test the same crash under Node 20/22 directly), but the combination of "declared runtime isn't supported by Cloud Functions at all" + "the specific failure is a namespace-property access failing only inside the Functions Emulator, not in a plain Node script outside it" is strong circumstantial evidence this is a Node-24/firebase-admin-v13 compatibility gap that the deployed (correctly-versioned) runtime wouldn't necessarily hit — but this is exactly why the fix doesn't rely on that theory alone.

**Two fixes applied, independent of which one is the "real" cause:**
1. `functions/package.json`: `engines.node` changed from `"24"` → `"20"`.
2. All five affected functions (`rehearsalReminder`, `checkGuestTokenExpiry`, `paymentWebhook`, `initiatePayment`, `mtnWebhook`) migrated from `admin.firestore.FieldValue`/`admin.firestore.Timestamp` namespace access to the modular `import { FieldValue, Timestamp } from "firebase-admin/firestore"` — the same pattern Phase 2b's `joinAsGuestDirector` already used successfully. `onProgramPublished` and `confirmAudioUpload` don't use this pattern at all — nothing to migrate there.

**Re-verified after the fix:** re-ran both the Phase 2b guest-join integration suite and Phase 3's new payment integration suite (see §Verification) against the real Functions Emulator — no crash reproduced anywhere in either suite, including the exact `initiatePayment`/`mtnWebhook` code paths that previously would have hit this. The emulator still warns `Your requested "node" version "20" doesn't match your global version "24". Using node@24 from host` (this dev machine only has Node 24 installed) — but that's now an explicit, visible warning about a local dev-environment mismatch, not a silent invalid config; the deployed function will run on the Node 20 container Google actually provisions for it.

---

## Fix 1 — fail-open signature checks + idempotency

**MTN's real callback authentication mechanism: still could not be confirmed.** Tried `momodeveloper.mtn.com/api-documentation/api-description` and `momoapi.mtn.com/api-documentation/callback` again via WebFetch — both are gated/JS-rendered portals; only navigation chrome came back, no technical content, same result as the original audit and Phase 2b.

**Interim approach implemented, exactly as you specified:** a shared secret (`MTN_WEBHOOK_SECRET`) embedded as a `?key=` query parameter in the `callbackUrl` that `initiatePayment` constructs and hands to MTN. This doesn't depend on MTN sending any particular header we can't verify — MTN has to round-trip the exact URL we gave it, query string included, to deliver the callback at all. Both `mtnWebhook` and `paymentWebhook` now share one `isAuthorizedWebhookRequest()` helper that **fails closed**: if the secret isn't configured, or the provided key is missing/wrong, the request is rejected (403) — there is no longer a code path where verification is silently skipped. A `TODO(payment-integrity)` comment is attached directly to the helper flagging that this needs confirmation against MTN's real spec before being trusted long-term, and suggesting cross-checking transaction status via MTN's authenticated `GET /requesttopay/{referenceId}` as a stronger future defense.

**`paymentWebhook` — flagged as apparently dead code, fixed anyway.** Grepped the whole repo: nothing (client or `initiatePayment`) ever targets this endpoint — only `mtnWebhook` is wired as the real callback destination. It looks like an earlier/legacy duplicate. I didn't delete it (removing an exported, potentially-still-deployed function is a deploy-affecting decision I'd rather you make explicitly), but it's a live public URL regardless of whether anything calls it today, so I locked it down with the same fail-closed check and added idempotency to it too. Recommend confirming nothing external targets it and deleting it in a future cleanup.

**Idempotency added to both:**
- `mtnWebhook`: checks `payment_requests/{referenceId}.status == 'completed'` before doing anything; if already completed, returns `200 {alreadyProcessed: true}` and does not touch `subscriptions` or `choirs` again. This directly closes the "replay a captured callback to extend the subscription forever" hole from the original audit.
- `paymentWebhook`: since it has no `payment_requests` backing (it never referenced that collection), idempotency is checked against `subscriptions/{choirId}` directly — if `txRef` matches and `status == 'active'` already, no-op.

---

## Fix 2 — `initiatePayment` double-response bug

Restructured with explicit early `return`s after every `res.*.json()` call — no code path can now reach a second response. **Verified this is actually fixed, not just theoretically restructured**: the integration test suite calls `initiatePayment` end-to-end (Test C) and confirms exactly one well-formed HTTP response comes back, with no `ERR_HTTP_HEADERS_SENT` crash — the exact scenario that crashed on every single call before this fix.

## Fix 3 — hardcoded MTN sandbox host

Base URL now derives from `mtnTargetEnv.value()`: `sandbox.momodeveloper.mtn.com` for `"sandbox"`, `momoapi.mtn.com` for `"production"`. **Could not verify MTN's actual production host against an authoritative source** — same portal-access problem as above. `momoapi.mtn.com` is used here based on third-party integration references (the same class of source the original audit's payment-agent used, not a live official spec page). **Flagged with an inline comment: confirm this against MTN's real docs before going live with real production payments.**

---

## Fix 4 — `billing_screen.dart` wired to the real backend

`_processPayment()` no longer fakes success. New flow:
1. Free plan selected → no payment needed, nothing charged (there's also no downgrade/cancel Cloud Function yet for an existing Pro choir switching to Free — out of scope here, flagged below).
2. Pro plan selected → calls `SubscriptionRepository.initiatePayment(...)`, which POSTs to the now-fixed `initiatePayment` Cloud Function with the signed-in user's real phone number (from `currentUserProvider`) and their Firebase ID token.
3. UI shows a genuine "Processing payment..." / "check your phone for the STK push" state, then **polls `payment_requests/{txRef}` via a live Firestore stream** (`watchPaymentRequestStatus`) for the webhook-driven `completed`/`failed` outcome — nothing client-side ever marks a subscription active.
4. A 2-minute client-side timeout shows a "Still Waiting" state (distinct from failure) if MTN's callback never arrives in that window, rather than hanging the UI forever.
5. All `createSubscription`/`updateSubscriptionStatus(active)` calls removed entirely — confirmed via grep that nothing else in the app called them either, so nothing else broke.

**Also fixed in the same repository, since it directly blocked Fix 4 from being testable:** `SubscriptionRepository.watchSubscription`/`getSubscription` previously queried the `subscriptions` collection by a `'choirId'` field on `.add()`-generated documents — but every server-side write (`mtnWebhook`/`paymentWebhook`) has always written to `subscriptions` using `choirId` itself as the document ID. These two shapes never matched; the read path was silently broken independent of anything else in this phase. Switched both to `.doc(choirId)` direct lookups, matching what the server actually writes.

---

## Fix 5 — server-side freemium cap (narrowly-scoped `firestore.rules` change)

**Flagging this explicitly and separately, same review discipline as Phase 2, per your instruction.**

Added two small helper functions (`choirData`, `isUnderSongLimit`) and one additional `&&` clause to the existing `songs` collection's `create` rule:
```
allow create: if isTenantMember(request.resource.data.choirId) &&
  hasAnyRole(request.resource.data.choirId, ['leader', 'director']) &&
  isUnderSongLimit(request.resource.data.choirId);
```
`isUnderSongLimit` reads `choirs/{choirId}.plan`/`.songCount` (confirmed field names match `choir.dart`'s `toJson()`) and allows creation if `plan == 'pro'` or `songCount < 3`. This closes the "any direct Firestore write bypasses the client-side-only check" hole from the original audit.

**Known residual limitation, not fixed by this rule (flagging rather than silently leaving unclear):** this does not fix the check-then-act race between this read and `SongRepository.incrementSongCount`'s separate, non-transactional write (documented in `PRODUCTION_READINESS_AUDIT.md` §1) — two concurrent creates could both read `songCount == 2` and both pass. A real fix needs a transactional create flow (e.g. move song creation through a Cloud Function using a Firestore transaction), which is out of scope for a rules-only change.

---

## Fix 6 — Airtel "coming soon"

`_ProviderCard` gained an optional `badge` label and a nullable `onSelect` (disabled when `null`, rendered at 50% opacity). The Airtel option now shows a "Coming soon" badge, cannot be tapped/selected, and `initiatePayment` independently rejects `provider != "mtn"` server-side with a matching "Airtel Money is coming soon" message — so even a client bypass can't reach a broken payment path.

---

## Verification

### 1. Nothing deployed. What needs deploying, for your review, once approved:
- `functions/src/index.ts` (all fixes above) + `functions/package.json` (`engines.node`)
- `firestore.rules` (Fix 5 only — one rule block; everything else in the file is unchanged from Phase 2/2b)
- No `storage.rules` changes this phase.
- Client (`billing_screen.dart`, `subscription_repository.dart`) ships with the next app release — no server deploy dependency there beyond the functions above being live first.

### 2. Emulator verification — 34 new/re-run tests, all passing

**Firestore + Storage rules suite** (re-ran full Phase 2/2b suite + 3 new Fix 5 tests):
```
23 passing — includes:
  ✔ a free-plan choir under the cap (songCount 2) CAN create a song
  ✔ a free-plan choir AT the cap (songCount 3) CANNOT create a 4th song directly via Firestore
  ✔ a pro-plan choir at/above songCount 3 CAN still create songs (no cap)
```

**Payment functions integration suite** (real Functions + Auth + Firestore emulators, `functions/.secret.local` used to give the emulator a known `MTN_WEBHOOK_SECRET` test value so the success/idempotency path could be exercised, not just the rejection paths — gitignored, never deployed):
```
17 passing:
  ✔ initiatePayment rejects a non-member of the choir (403)
  ✔ initiatePayment rejects unauthenticated requests (401)
  ✔ initiatePayment returns exactly one HTTP response — the double-response bug is gone
  ✔ initiatePayment rejects Airtel cleanly (400, plain-English message)
  ✔ mtnWebhook rejects requests with no key (403, fail-closed)
  ✔ mtnWebhook rejects requests with a wrong key (403, fail-closed)
  ✔ paymentWebhook rejects missing/wrong key the same way (403, fail-closed)
  ✔ mtnWebhook with the correct key succeeds: payment_request → completed,
    subscriptions/{choirId} created with plan: pro / status: active, choirs/{choirId}.plan → pro
  ✔ replaying the same completed webhook is a no-op — alreadyProcessed: true,
    startDate/endDate NOT re-extended
```

**Guest-director regression check** (Phase 2b's suite, re-run to confirm Fix 0b's shared changes to `index.ts`/`package.json` didn't break it): 11/11 still passing, no regressions.

**`flutter analyze`**: clean. **`tsc --noEmit`**: clean.

### 3. End-to-end trace: tap-to-active, with every trust boundary called out

Home → Billing → select Pro → select MTN → Confirm → tap "Pay Now" → `_processPayment()` reads the signed-in user's **real** phone number from `currentUserProvider` (not client-entered, not fakeable) → `SubscriptionRepository.initiatePayment()` POSTs to `initiatePayment` with the user's **verified Firebase ID token** → Cloud Function verifies the token server-side (`admin.auth().verifyIdToken`), confirms the caller is **actually a member of `choirId`** (server-side Firestore check, not trusted from the client), calls MTN's sandbox/production API for a real `requesttopay`, embeds the webhook secret in the `callbackUrl` it gives MTN, and writes a `pending` `payment_requests/{txRef}` doc — **the client never writes anything to `payment_requests` or `subscriptions` itself; both are Admin-SDK-only writes, and `firestore.rules` still blocks client writes to both.** MTN sends the user an STK-style prompt on their actual phone; the user approves/rejects it *outside this app entirely*. MTN calls back to `mtnWebhook?key=<secret>` — rejected outright if the key doesn't match — which checks idempotency, then writes `subscriptions/{choirId}` and updates `choirs/{choirId}.plan` **only from that server-side webhook**, never from anything the client asserted. The client, meanwhile, is only ever *watching* `payment_requests/{txRef}` and `subscriptions/{choirId}` — it reads the outcome, it never sets it. **No step in this chain depends on client-side trust for the actual state transition to "pro."**

---

## Doc-verification appendix

| Claim | Source | Result |
|---|---|---|
| Cloud Functions 2nd gen supported Node versions (22/20/18-deprecated; 24 unsupported) | `firebase.google.com/docs/functions/manage-functions?gen=2nd` | **Verified live** |
| `firebase-functions/params` exposes a built-in `projectID` parameter | `firebase.google.com/docs/functions/config-env` | **Verified live** |
| No automatic env var exposes a function's own project ID/URL in raw Cloud Functions (2nd gen) | `docs.cloud.google.com/functions/docs/configuring/env-var` | **Verified live** (redirect followed from `cloud.google.com/functions/docs/configuring/env-var`) |
| MTN MoMo Collections API callback authentication mechanism (signature/HMAC/header) | `momodeveloper.mtn.com/api-documentation/api-description`, `momoapi.mtn.com/api-documentation/callback` | **Could not verify** — both gated/JS-rendered portals, no technical content returned either attempt |
| MTN production Collections API host (`momoapi.mtn.com`) | third-party integration references only | **Could not verify against an authoritative source** — flagged inline in code and here |
| Root cause of the `FieldValue`/`Timestamp` emulator crash (Node 24 vs. Cloud Functions supported runtimes) | Inferred from the above Node-version doc + reproducible emulator behavior; not a live A/B test under Node 20/22 (only Node 24 installed, no version manager in this environment) | **Best-supported hypothesis, not conclusively proven** — the fix (modular imports + corrected `engines.node`) resolves the observed symptom regardless of whether this specific mechanism is exactly right |

---

## Open flags for your review

1. **MTN callback authentication is still an unverified interim scheme** (shared secret in the callback URL). Needs confirmation against MTN's real Collections API spec before being trusted for real production payments — requires actual portal login access, which this environment doesn't have.
2. **MTN production host (`momoapi.mtn.com`) is unverified** — same access limitation.
3. **`paymentWebhook` appears to be dead/orphaned code** — fixed rather than removed, since deleting an exported function is a deploy-affecting call I left to you. Consider removing it once you've confirmed nothing external targets it.
4. **No downgrade/cancel path exists** for a Pro choir selecting Free in the billing UI — `_processPayment()` currently treats any Free selection as a no-op success screen. This wasn't in Fix 4's scope (which was about the payment flow specifically) but is a real gap if downgrade is an expected product flow.
5. **The Fix 5 rules change doesn't close the check-then-act race** on `songCount` (see Fix 5 above) — a transactional creation flow is the real fix, out of scope here.
6. **Root cause of Fix 0b's crash isn't 100% conclusively isolated** (see doc-verification table) — the fix should hold regardless, but if functions still misbehave post-deploy, this is the first place to look.

Awaiting your review before deploying Phase 3 (or Phase 2 + 2b + 2c + 3 together) and before moving to Phase 4.
