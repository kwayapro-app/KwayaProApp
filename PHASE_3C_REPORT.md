# Phase 3c Report — Webhook Callback URL Verification

**Scope:** verification only, against the live deployed project. No rules, no functions logic. **Comment-only changes** to `functions/src/index.ts`, `rehearsal_repository.dart`, `subscription_repository.dart` — no behavioral code changed.

---

## Step 1: Ground truth

**Docs check:** `firebase.google.com/docs/functions/http-events?gen=2nd` does not explicitly state whether the legacy `https://REGION-PROJECTID.cloudfunctions.net/FUNCTIONNAME` format reliably routes to a 2nd-gen (Cloud Run-backed) function — it only says to use "the exact URL output from the CLI after deployment" and separately mentions the `*.run.app` format exists for the Dart SDK. Not conclusive either way, so per your instruction I didn't assume — tested directly against the live project instead.

**Live HTTP test results** (both endpoints are the live, currently-deployed `mtnWebhook`):

```
$ curl -s -o /dev/null -w "%{http_code}" -X POST \
    https://us-central1-kwayapro-app.cloudfunctions.net/mtnWebhook
403

$ curl -s -o /dev/null -w "%{http_code}" -X POST \
    https://mtnwebhook-oh5mmorzca-uc.a.run.app
403
```

Status codes alone could theoretically both be coincidental platform-level 403s, so I also compared response **bodies** to confirm both are actually executing our function's own logic, not just a generic gateway rejection:

```
$ curl -s -X POST https://us-central1-kwayapro-app.cloudfunctions.net/mtnWebhook
{"error":"Invalid or missing webhook credentials"}

$ curl -s -X POST https://mtnwebhook-oh5mmorzca-uc.a.run.app
{"error":"Invalid or missing webhook credentials"}
```

Identical, and that exact string only appears in one place in the codebase: `isAuthorizedWebhookRequest`'s rejection path in `mtnWebhook`. **Both URL formats route to the same live, currently-deployed function.** Also spot-checked with a wrong `?key=` on both to confirm the fail-closed check itself works identically through either address (both 403).

**Extended the same check to every other HTTP function referenced client-side**, since the same risk applies to all of them (per your instruction to re-check `joinAsGuestDirector` and `cancelSubscription` too):

```
$ curl -s -X POST https://us-central1-kwayapro-app.cloudfunctions.net/joinAsGuestDirector
{"error":"You must be signed in to accept this invite."}

$ curl -s -X POST https://us-central1-kwayapro-app.cloudfunctions.net/cancelSubscription
{"error":"You must be signed in to do this."}

$ curl -s -X POST https://us-central1-kwayapro-app.cloudfunctions.net/initiatePayment
{"error":"You must be signed in to do this."}
```

All three return exactly their own source code's real error message (401, matching each function's own `authHeader?.startsWith("Bearer ")` check) via the `cloudfunctions.net` format — confirmed live and correctly reachable, not a 404.

---

## Step 2: Fix

**No functional/URL change needed anywhere** — every function tested is correctly reachable via the `cloudfunctions.net` format already in use throughout the codebase (`mtnWebhook`'s `callbackUrl` in `initiatePayment`, `_guestJoinFunctionUrl` in `rehearsal_repository.dart`, `_initiatePaymentUrl`/`_cancelSubscriptionUrl` in `subscription_repository.dart`).

Per your instruction for the "both work" case, added explanatory comments at all four call sites rather than changing anything:
- `functions/src/index.ts` (the `callbackUrl` construction in `initiatePayment`) — documents the empirical verification and explains *why* the `cloudfunctions.net` format was kept over switching to the `*.run.app` address: the Cloud Run URL embeds a deploy-specific random hash (`oh5mmorzca`) that isn't derivable from `projectID`/region alone, and — checked against current docs (`firebase.google.com/docs/functions/config-env?gen=2nd`) — **no Firebase Functions built-in parameter or API exposes a function's own live `*.run.app` URL at runtime**; the only built-in params are `projectID`, `databaseURL`, and `storageBucket`. So even if we wanted to prefer the Cloud Run-native format, there's no clean programmatic way to construct it, and a configured/hardcoded value would carry the same "could drift on redeploy" risk either way. The `cloudfunctions.net` format avoids that risk entirely since it's derived purely from `projectID` (a real built-in param) plus a fixed region/function name — nothing deploy-specific to go stale.
- `rehearsal_repository.dart` and `subscription_repository.dart` — shorter notes confirming the same live-verification result for `joinAsGuestDirector`, `initiatePayment`, and `cancelSubscription`.

---

## Verification

1. **Live curl results shown above** for all four functions — not theoretical, actual HTTP responses from the deployed project.
2. **No re-run of the Phase 3 payment integration suite** — per the task's own conditional ("if callbackUrl changes"), nothing changed here beyond comments, so there's no behavior to regression-test. `flutter analyze` and `tsc --noEmit` both still clean (comment-only edits, confirmed they didn't break anything trivial like unterminated strings).
3. **Confirmation: every function-to-function or client-to-function call in this codebase uses the `https://us-central1-kwayapro-app.cloudfunctions.net/<FunctionName>` format, uniformly, and every one of them has now been verified live and reachable in exactly that form**:
   - `initiatePayment`'s `callbackUrl` → `mtnWebhook` (verified both formats work; kept `cloudfunctions.net`)
   - `RehearsalRepository._guestJoinFunctionUrl` → `joinAsGuestDirector` (verified)
   - `SubscriptionRepository._initiatePaymentUrl` → `initiatePayment` (verified)
   - `SubscriptionRepository._cancelSubscriptionUrl` → `cancelSubscription` (verified)

No open flags from this phase — this was a clean confirmation, not a fix. All prior phases' open flags (MTN callback auth mechanism unverified, MTN production host unverified, Fix 5's residual `songCount` race, `paymentWebhook` removal requiring a functions deploy to take effect) still stand, unchanged.
