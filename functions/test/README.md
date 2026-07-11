# Functions integration tests

Committed in Phase 7 to close a real gap: every prior phase (2b, 3, 3b, 6)
tested `joinAsGuestDirector`, `initiatePayment`, `mtnWebhook`, and
`cancelSubscription` against the real Functions + Auth + Firestore
emulators, but only from ephemeral session-scratchpad scripts that were
never committed — meaning there was **zero persisted test coverage** for
the app's payment/subscription logic despite it being the highest-risk code
in the repo. `integration.js` consolidates that coverage into one committed
suite.

## Running

1. Create `functions/.secret.local` (gitignored via `functions/.gitignore`'s
   `*.local` pattern — never commit real values here) with a test value for
   the webhook secret:

   ```
   MTN_WEBHOOK_SECRET=test-webhook-secret-value
   ```

   The Functions emulator reads secrets from this file automatically.

2. From the repo root:

   ```bash
   cd functions && npm run build && cd ..
   MTN_WEBHOOK_SECRET_TEST_VALUE=test-webhook-secret-value \
     firebase emulators:exec --config firebase.test.json \
     --project=kwayapro-app "node functions/test/integration.js"
   ```

   The env var passed to the test script must match the value written to
   `functions/.secret.local` exactly, since the test needs to construct a
   `?key=...` query string matching what the emulator-loaded function will
   check.

## Scope — what this does and doesn't cover

- **Fully covered, end to end, against real emulators:** `joinAsGuestDirector`
  (auth, expiry, single-use consumption, replay rejection), `mtnWebhook`
  (fail-closed auth, the full SUCCESSFUL/FAILED state transitions, replay
  idempotency), `cancelSubscription` (auth, role gating, state transition,
  double-cancel rejection), and confirmation that `paymentWebhook` is
  genuinely removed (404).
- **Deliberately NOT covered:** `initiatePayment`'s actual outbound call to
  MTN's Collections API (token exchange + `requesttopay`) — that requires
  live MTN sandbox credentials and network access this environment doesn't
  have. What IS covered is every auth/validation/authorization check
  `initiatePayment` performs *before* that outbound call (unauthenticated,
  invalid token, non-member, Airtel-rejected, missing fields) — the same
  boundary the Phase 3 emulator testing used.
- MTN's real callback authentication mechanism and production API host
  remain unverified against authoritative MTN documentation (see
  `PRODUCTION_READINESS_FINAL_SUMMARY.md`) — this suite tests the app's own
  logic, not MTN's real-world behavior.
