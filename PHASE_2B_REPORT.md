# Phase 2b Report — Pre-Deploy Blockers

**Scope:** resolves the three open flags from `PHASE_2_REPORT.md` §1/§2/§3. Touches `firestore.rules`, `storage.rules`, `functions/src/index.ts` (one new Cloud Function + one new trigger, existing payment/webhook functions untouched), and the specific Dart call sites needed to wire the client to the new function and stop the now-blocked cross-user read. **Not deployed.**

---

## Fix 1 — Guest-director grant via Cloud Function

### What was built
`functions/src/index.ts`: new `joinAsGuestDirector` (`onRequest`, matching the existing style of every other function in the file — none of them use `onCall`, so I kept that convention rather than introducing a second pattern).

1. Verifies the caller's Firebase ID token via `admin.auth().verifyIdToken()` — **this is stricter than every existing function in the file**, which only check that an `Authorization` header is *present*, never that it's a valid token (see `getPresignedUrl`, `initiatePayment`). I flagged this gap rather than silently fixing it elsewhere (out of scope — those are Phase 3/payment functions), but my new function needs the caller's real, verified `uid` to write the membership doc correctly, so it does this properly.
2. Looks up `rehearsal_sessions` by `guestToken` — the same query `RehearsalRepository.validateGuestToken`/`getSessionByToken` used to run client-side, ported server-side rather than reimplemented from scratch.
3. Checks `guestTokenExpiry > now` server-side, at the moment of grant — this is the actual fix for the original audit's "guest director token expiry is only enforced by a 30-minute scheduled cleanup" finding.
4. Writes the `choir_memberships` doc via the Admin SDK (bypasses rules, correctly).
5. Returns a plain-English error per failure mode: 401 (not signed in / bad token), 404 (invalid or already-used token), 410 (revoked or expired), 500 (session missing its choirId).

### A discovery this flow depends on, worth restating plainly
I re-verified something `PHASE_2_REPORT.md` §3 predicted but didn't fully spell out: the **old client-side `validateGuestToken`/`getSessionByToken` flow could never have worked** under any choir-scoped `rehearsal_sessions` read rule, Phase 2 or not — `allow read: if isTenantMember(resource.data.choirId)` requires the reader to already be a member, but a guest by definition isn't one yet. So this wasn't just "blocked by the new rules," it was *already broken* by the pre-Phase-2 rules too, for a different reason (query permission denial rather than the membership-create hole). Moving this server-side fixes both problems in one place.

### Single-use — now enforced, wasn't before
I checked: the pre-Phase-2b implementation never invalidated a guest token after use. `revokeGuestToken` only ran on manual leader action, and `checkGuestTokenExpiry`'s scheduled cleanup only fires up to 30 minutes after expiry. So a leaked/shared invite link could be used by multiple different people within the validity window, not just the intended one recipient — "Generate a one-time invite link for someone" (the screen's own copy) wasn't actually one-time. My function deletes `guestToken`/`guestTokenExpiry` from the session immediately on a successful grant, making it genuinely single-use. `isGuestDirector` is left `true` (a guest director now legitimately exists for that session) rather than reset to `false` (which would incorrectly imply no guest was ever assigned).

### Client changes
- `RehearsalRepository`: removed `validateGuestToken`/`getSessionByToken` (provably broken, see above), added `joinAsGuestDirector(token)` which POSTs to the new function with the user's ID token and returns a typed result or a `GuestJoinException` with a plain-English message.
- `app_router.dart`'s `_RehearsalInviteScreenState._validateToken()`: now calls the single new method instead of the old three-call sequence. Also fixes a pre-existing PRD 9.3 violation in passing — the old catch block did `_error = 'Error: $e'` (raw exception text); now it surfaces `GuestJoinException.message` (already plain English from the function) or a generic fallback.
- `ChoirRepository.addGuestDirector` was deleted (its only caller was the code above; the Cloud Function replaces its entire responsibility).

### ⚠️ New flag: hardcoded Cloud Functions URL / project ID mismatch
`RehearsalRepository` hardcodes `https://us-central1-kwayapro-app.cloudfunctions.net/joinAsGuestDirector`, using the project ID from `.firebaserc` (`kwayapro-app`). While doing this I noticed `functions/src/index.ts`'s existing MTN webhook callback URL hardcodes a **different** project ID: `https://us-central1-kwayapro-production.cloudfunctions.net/mtnWebhook`. One of these is wrong, and I can't tell which from the repo alone — flagging for you to confirm which Firebase project is actually live before either function is deployed or called. If it's `kwayapro-production`, my new client-side URL needs updating too.

### Traced end-to-end
Link tap → `/rehearsal-invite/:token` route → `_RehearsalInviteScreenState._validateToken()` → `RehearsalRepository.joinAsGuestDirector(token)` → HTTP POST with the user's verified ID token → Cloud Function validates token + expiry server-side → Admin SDK writes `choir_memberships/{choirId}_{uid}` with `role: 'director'` and real display name → token consumed → function returns `{choirId, sessionId}` → client sets `activeChoirIdProvider` → user is now a real tenant member of that choir under the Phase 2 rules → every subsequent read (rehearsal sessions, songs, chat, etc.) works normally through ordinary client-side rules, no special-casing needed. Verified against a real Functions + Auth + Firestore emulator run (§4).

---

## Fix 2 — Denormalized names

### Root cause fixed at every write site
- `onboarding_screen.dart`: both the choir-creation (leader) and in-onboarding join (chorister) membership writes now use `userName` — the real name already computed a few lines above for the `AppUser` doc (`_nameController.text` if provided, else `user.displayName`, else `user.phoneNumber`) — instead of `user.displayName ?? 'Leader'/'Member'`. Since phone-OTP auth (the app's primary auth method) essentially never populates `user.displayName`, the old code was hitting the `'Leader'`/`'Member'` placeholder branch almost every time in practice.
- `ChoirRepository.joinChoir` (the `/join/:inviteCode` deep-link flow): now does a self-read of `users/{userId}` (always permitted — it's always the caller's own uid) to get their real name before writing the membership, instead of the hardcoded literal `'Member'`.
- `joinAsGuestDirector` Cloud Function: reads the guest's real name via Admin SDK (bypasses rules) instead of writing `'Guest Director'` unconditionally.

### `watchMembership` / `watchMembers` simplified
Both now do a plain `snapshot.data()`/`doc.data()` map with no cross-read. The `async*` generator and per-member `try { fetch users/{userId} } catch { 'Unknown' }` loop are gone entirely — not just made unnecessary, actually deleted, since the whole point was to stop depending on a read path the Phase 2 rules correctly block.

### Confirmed complete — re-grepped per your instruction
Beyond `watchMembership`/`watchMembers`, I re-checked for any other cross-user `users/{userId}` read: only `onboarding_screen.dart` (self, for the `AppUser` doc itself), `user_repository.dart`/`auth_repository.dart` (self, auth-related), and now `ChoirRepository.joinChoir`/the Cloud Function (both self or Admin-SDK, both fine). **No other place in the app reads another user's profile document.** `profilePhotoUrl` is never displayed for anyone other than the profile owner (only referenced in `app_user.dart` and `profile_screen.dart`) — `ChoirMembership` has no photo field at all, so there was nothing to denormalize there.

### Backfill approach: both, for different reasons — not a real choice between them
I initially framed this as "pick one," but they solve different problems and you need both:
- **Ongoing sync (`onUserProfileUpdated` Firestore trigger, implemented):** without this, the moment anyone changes their display name in `profile_screen.dart`, their membership docs go stale again — this isn't a backfill problem, it's a permanent requirement now that the live cross-read is gone. Fires only on an actual `name` change, batch-updates every `choir_memberships` doc for that `userId`.
- **One-time backfill (`functions/scripts/backfill-membership-names.js`, written, NOT run):** the trigger above only fixes documents *going forward*, from the next time a user touches their own profile. It does nothing for the `'Member'`/`'Leader'`/`'Guest Director'`/`'Unknown Member'` placeholders already sitting in existing production membership docs — those users may never touch their profile again, leaving stale placeholders indefinitely. The script scans every `choir_memberships` doc, and for any with a known-placeholder name, looks up the real name from the corresponding `users/{userId}` doc and updates it. Supports `--dry-run` to preview changes with zero writes. **I did not run this against your production project** — it needs a service account key you hold, per the instructions. Usage is documented in the script's header comment.

---

## Fix 3 — `/scores` write: leader/director only

`storage.rules`'s `canManageScores(choirId)` no longer checks the `'score_librarian'` permission flag — it's now identical to `isChoirManagement(choirId)` (leader/director only), matching your explicit decision.

### UI check
I re-grepped for any UI gating on `canManageScores`/`score_librarian`: **there is no score-upload screen in the app at all** — `score_repository.dart`/`score_providers.dart`/`score_attachment.dart` exist at the data/domain layer, but no `presentation/` screen wires them up. So there's no "dead-end upload button" to flag — that control doesn't exist yet.

What *does* exist: `member_detail_screen.dart`'s permission-toggle UI lets a leader grant a chorister the `'score_librarian'` permission flag (alongside `'audio_uploader'`, `'attendance_manager'`, `'song_program_planner'`). After this fix, toggling `'score_librarian'` on for someone is **now a complete no-op** — it grants a permission flag that no rule anywhere honors and no UI anywhere consumes. This isn't a broken control mid-flow (nothing fails on tap), but a leader granting this permission would reasonably expect it to do something. Flagging as requested rather than fixing — options for a future phase: remove `'score_librarian'` from the togglable permission list entirely (cleanest, since there's no consuming feature yet), or leave it as forward-compatible scaffolding for when a scores UI ships and re-add the Storage delegation at that point.

---

## 4. Verification

### Emulator test suite — 31/31 passing across two runs

**Rules suite** (Firestore + Storage emulators, `@firebase/rules-unit-testing`) — re-ran the full Phase 2 suite plus 3 new `/scores` tests:

```
choir_memberships create — self-elevation (Fix 1)          7 passing  (unchanged from Phase 2)
users/{userId} read scoping (Fix 2)                         3 passing  (unchanged from Phase 2)
storage.rules choir-scoping (Fix 3)                          9 passing  (6 unchanged + 3 new)
  ✔ Phase 2b Fix 3: a chorister with 'score_librarian' permission CANNOT write to /scores
  ✔ a director CAN write to /scores (leader/director only, no delegation)
  ✔ a plain chorister (no permission) CANNOT write to /scores

20 passing (4s)
```

**Guest-director integration suite** (real Functions + Auth + Firestore emulators — the rules-unit-testing harness can't exercise actual HTTP function logic, so this needed the full emulator suite plus a real ID token from the Auth emulator's REST API):

```
✔ returns 401 with no Authorization header
✔ returns 410 for an expired token
✔ returns 200 (valid token)
✔ response choirId matches
✔ response sessionId matches
✔ membership document was created
✔ role is director
✔ name is the REAL display name, not a placeholder     <- Fix 2, end-to-end
✔ permissions match the intended guest-director grant
✔ guestToken was deleted from the session after use (single-use)
✔ returns 404 on replay of a consumed token             <- single-use enforcement

11 passing, 0 failing
```

I did not write a separate Dart-level test for `watchMembership`/`watchMembers` returning real names — there's no existing Firebase-emulator-backed Flutter test harness in this repo to extend, and building one from scratch felt like scope creep for this phase. Instead: the integration test above directly proves the membership document ends up with the real name field, and `watchMembership`/`watchMembers` are now (verified by reading the code) a plain, untransformed `snapshot.data()` map — there's no remaining logic between "what's in the document" and "what the UI sees" left to test.

### A real bug this testing surfaced (not part of the requested fixes, fixed anyway because it blocked verification)
`admin.firestore.FieldValue.serverTimestamp()`/`.delete()` — used throughout the pre-existing code (`checkGuestTokenExpiry`, `initiatePayment`, `mtnWebhook`, `rehearsalReminder`, `onProgramPublished`) — **reproducibly threw `Cannot read properties of undefined` inside the actual Firebase Functions Emulator** the first time I exercised that code path for real (my new function hit it immediately). It works fine in a plain Node script outside the emulator, so this is emulator/runtime-specific, not a logic error — but it means **none of the functions using this pattern could currently be locally tested against the emulator**, and I have no way to confirm from this repo alone whether the same failure mode reaches production. I fixed it only in my new code, by switching to the modular `import { FieldValue } from "firebase-admin/firestore"` (the currently-recommended pattern) instead of the `admin.firestore.FieldValue` namespace access. **I did not touch the pre-existing occurrences** in the payment/webhook functions — out of scope for this phase — but flagging clearly: this needs a look in Phase 3, since `initiatePayment`/`mtnWebhook` both use the same broken pattern for `Timestamp`/`FieldValue`, and if this reproduces in production the same way it did in the emulator, subscription writes would fail outright.

### `flutter analyze` and `tsc --noEmit`: both clean after every change.

---

## 5. Manual steps — checking which `firestore.rules` are actually live in production

I don't have Firebase console access, so I can't check this myself. Here's how to check it yourself, given Phase 2 found the committed rules file couldn't have compiled (the `let`-in-match-block bug, now fixed):

1. Go to **console.firebase.google.com** and open the project. First confirm you're looking at the right one — Phase 2b turned up a project ID inconsistency (`kwayapro-app` per `.firebaserc` vs. `kwayapro-production` hardcoded in the MTN webhook callback URL); check **Project Settings (gear icon) → General → Project ID** against both of those.
2. In the left sidebar: **Build → Firestore Database → Rules** tab. This shows the *currently deployed* rules content directly — compare it against this repo's `firestore.rules`. If it doesn't contain the `hasAnyRole`/`getMembershipData` helper functions and the collection-by-collection structure this repo has, the deployed rules are from a different source entirely (possibly the Firebase-default "allow all during development" template, or an older/different rules file than anything in this repo).
3. Same screen, click the **"Rules playground"** tab (or the history icon near the top) — this shows a **version history** of every rules deployment with timestamps. If there's no history, or the most recent entry predates this project's real feature work, that's strong evidence the current `firestore.rules` (with its pre-existing `let` bug) was never successfully deployed.
4. Repeat for **Build → Storage → Rules** to check the live storage rules the same way, given Phase 1 found the root `storage.rules` was a deny-all that didn't match `kwayapro/storage.rules`'s working version.
5. If you have the Firebase CLI authenticated locally (`firebase login`, already confirmed working in this environment) and want a non-console way to check: `firebase deploy --only firestore:rules --dry-run` against the correct project (once identified in step 1) will show whether the CLI considers the local file different from what's deployed, without actually deploying anything. I'm not running this myself since it requires picking the correct project ID first, which is your call given the mismatch in step 1.

---

## 6. Summary of files changed

- `firestore.rules` — no further changes this phase (already correct from Phase 2).
- `storage.rules` — `canManageScores` no longer honors `'score_librarian'`.
- `functions/src/index.ts` — added `joinAsGuestDirector`, added `onUserProfileUpdated` trigger, added modular `FieldValue` import (used only in the new code).
- `functions/scripts/backfill-membership-names.js` — new, not run.
- `kwayapro/lib/features/choir/data/choir_repository.dart` — `joinChoir` now denormalizes the real name; `watchMembership`/`watchMembers` simplified (no cross-read); `addGuestDirector` deleted.
- `kwayapro/lib/features/rehearsal/data/rehearsal_repository.dart` — `validateGuestToken`/`getSessionByToken` removed (provably broken under any choir-scoped rules); `joinAsGuestDirector` client method added.
- `kwayapro/lib/features/auth/presentation/onboarding_screen.dart` — both membership-creation call sites now write the real name.
- `kwayapro/lib/core/router/app_router.dart` — `_validateToken()` rewritten around the new single Cloud Function call; also stops surfacing a raw exception string on failure.

## 7. Open flags carried forward
1. **Project ID mismatch** (`kwayapro-app` vs `kwayapro-production`) — needs your confirmation before either the new function's client URL or the existing payment webhook URLs can be trusted (§Fix 1).
2. **`admin.firestore.FieldValue`/`.Timestamp` namespace access reproducibly broken in the Functions Emulator** for the pre-existing payment/scheduled functions — not fixed (out of scope), needs attention in Phase 3 (§4).
3. **Backfill script written but not run** — needs you (or someone with project credentials) to run `node functions/scripts/backfill-membership-names.js --dry-run` first, review, then without the flag.
4. **`'score_librarian'` permission toggle is now a no-op** in `member_detail_screen.dart` — not fixed, flagged for a future decision (§Fix 3).
5. Confirm which Firebase rules are actually live per §5 before assuming Phase 1/2/2b changes are additive vs. a first-ever real deployment.

Awaiting your review before deploying Phase 2 + 2b together, then before Phase 3.
