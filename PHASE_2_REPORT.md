# Phase 2 Report — Security Rules Hardening

**Scope:** `firestore.rules` and `storage.rules` only, per PRODUCTION_READINESS_AUDIT.md action items 4–5 and the storage-rules gap identified in `PHASE_1_REPORT.md`. No app code, data models, or payment/webhook code was touched.
**Not deployed.** Per your instruction, these changes are working-tree only, awaiting your review and manual `firebase deploy --only firestore:rules,storage`.

---

## 0. A bug found before I could test anything

Before any of my changes could be verified, the Firestore emulator refused to compile the **existing, unmodified** `firestore.rules`:

```
Error compiling rules:
L155:11 Missing 'match' keyword before path.
L156:7 Unexpected 'let'.
```

Root cause: the `attendance` rule used `let choirId = attendanceId.split('_')[0];` **directly inside a `match` block**. I verified against the official Firestore Rules documentation (`firebase.google.com/docs/firestore/security/rules-structure`) — `let` bindings are documented **only** for use inside function bodies, not at match-block scope. This is invalid syntax and would fail a real `firebase deploy` today, independent of anything in this phase.

**Fix applied** (necessary prerequisite, not one of the requested items, but required for the file to compile at all): replaced the `let` with a helper function, `attendanceChoirId(attendanceId)`, matching the file's existing helper-function style, called inline in both `allow` conditions. Functionally identical — `attendance` read/write behavior is unchanged.

This means: **as of the start of this phase, `firestore.rules` could not have been successfully deployed.** Whatever rules are actually enforcing your production Firestore right now are either an older, different version, or the project has no rules deployed from this file. Worth confirming directly in the Firebase console before assuming any rules content in this repo reflects live production behavior.

---

## 1. Fix 1 — `choir_memberships` self-elevation

### What changed
- **Create**: self-serve creation (`request.resource.data.userId == request.auth.uid`) is now restricted to `role == 'chorister'` only, **except** a self-assigned `role == 'leader'` is allowed if — and only if — `getAfter()` shows the `choirs/{choirId}` document (in the same transaction/batch, or already existing) has `leaderId == request.auth.uid`. `role == 'director'` can no longer be self-granted via create, under any condition.
- **Update** (a gap I found while auditing, not explicitly listed but required for Fix 1 to mean anything): the existing self-update branch (`request.auth.uid == resource.data.userId`) had **no field restriction** — a chorister could call `update({role: 'director'})` on their own membership doc and get the exact same escalation the create-rule fix was meant to close, just via a different write. I added a guard: self-updates are only allowed if `role` and `permissions` are unchanged. Leader/director updates to **any** membership (including changing someone else's role or permissions) are untouched.
- **`choirs` create** (a small supporting change, same file, needed for the `getAfter()` check above to be trustworthy): added `request.resource.data.leaderId == request.auth.uid`, so a user can't fabricate a choir document claiming someone else — or a role check target — as `leaderId`. Previously `choirs create` had no field validation at all.

### Why this combination, and not something narrower
I traced every place the app actually creates or updates a `choir_memberships` document (3 call sites total: `onboarding_screen.dart`'s choir-creation batch, `ChoirRepository.joinChoir`, and `ChoirRepository.addGuestDirector`) plus the one update call site (`member_detail_screen.dart`'s permission toggle, always a leader/director acting on someone else's doc). That's the complete legitimate surface — nothing else touches this collection.

### ⚠️ Known regression — flagging for your decision, not deciding it myself
**The guest-director "join via link" flow is now broken.** `ChoirRepository.addGuestDirector` self-creates a membership with `role: 'director'` for the invited guest — this was, and remains, indistinguishable in the data model from the vulnerability itself: `ChoirMembership` documents carry no reference back to the originating rehearsal session or guest token, so there is no rules-only way to say "this specific director self-creation is legitimate because a valid, unexpired guest token exists" — Firestore Rules cannot run an arbitrary query ("does a rehearsal_sessions doc with this choirId and an unexpired guestToken exist"), only `get()`/`exists()`/`getAfter()` on a **known, specific document path**, and the membership write doesn't carry a sessionId to look up.

I chose to close the hole completely rather than leave any self-serve director path open, because the alternative — some heuristic that's "probably fine" — would just be a differently-shaped version of the same vulnerability.

**Recommended real fix (out of scope for this rules-only phase):** move guest-director grants server-side into a Cloud Function that (a) validates the token and its expiry using `RehearsalRepository.validateGuestToken`'s existing logic, then (b) uses the Admin SDK to write the `choir_memberships` document — Admin SDK writes bypass security rules entirely, which is the architecturally correct place for this, since it also lets the function enforce `guestTokenExpiry` in real time at the moment of grant (see §3 below on why a rules-only expiry check isn't achievable either). This directly addresses the original audit's "guest director token expiry" item at the same time.

**Until that Cloud Function exists, tapping a guest-director invite link will fail** at the `addGuestDirector` step with a permission-denied error. This is a functional regression versus today's (insecure) behavior, traded for closing a real self-elevation hole. If you'd rather stage this — e.g., ship the PII/audio fixes now and hold the `choir_memberships` create/update change until the Cloud Function is ready — say so and I'll split it out.

### Traced: does the legitimate promotion flow still work?
Yes. `member_detail_screen.dart`'s `_togglePermission` (the only production update call site) always calls `updateMembership(choirId, targetUserId, {...})` where `targetUserId` is the member being managed, not the caller — so it always hits the `hasAnyRole(choirId, ['leader','director'])` branch, unaffected by the new self-update field restriction. Verified by test ("an existing leader CAN promote a chorister to director via UPDATE").

### Traced: does choir creation still work?
Yes, but note it was **arguably broken before this phase too** in a different way: the old rule only allowed self-create with `role in ['chorister', 'director']` — it never included `'leader'` at all, and the onboarding choir-creation flow self-creates the founder's membership with `role: 'leader'`. Unless something I haven't seen intercepts this, choir creation would have failed permission checks even before my change. My fix explicitly adds the `'leader'` + `getAfter()` branch, which both closes the gap I was asked to close AND appears to fix this separate, pre-existing functional gap. Verified by test ("creating a choir + self-membership as leader in one batch SUCCEEDS").

---

## 2. Fix 2 — `users/{userId}` PII exposure

### What changed
`allow read: if isOwner(userId);` — was `if isAuthenticated();`.

### Why I didn't implement a "shared choir" check instead
I want to be upfront that this is a stricter fix than what was asked for, and here's why: a true "requester shares at least one choir with the target user" check is **not expressible in Firestore Rules without either a query capability rules don't have, or a data-model change** (denormalizing a list of member UIDs onto the choir doc, or a list of choir IDs onto the user doc — both out of scope for a rules-only phase). Firestore Rules can only `get()`/`exists()` a **specific, known document path** — and a plain `users/{userId}.get()` request carries no choir context for the rule to check against. There's no way to ask "does there exist *some* choir where both of these UIDs are members" without iterating over the requester's memberships, which rules cannot do.

Given that constraint, the only two honest options were: owner-only (correct, but stricter), or leave it open (the current vulnerability). I implemented owner-only.

### ⚠️ Real functional impact — please review before deploying this specific rule
I traced every place the app reads **another** user's `users/{userId}` document (not their own): only `ChoirRepository.watchMembership` and `ChoirRepository.watchMembers` (both in `choir_repository.dart`), used to show live member names/photos in the member list, member detail screen, and attendance roster. Chat already denormalizes `senderName` onto each message, so chat is unaffected.

This is a real, visible regression: those two methods will start throwing/falling back to `'Unknown'` (they already have a `catch (_) { yield membership.copyWith(name: 'Unknown') }` fallback for lookup failures — so the app won't crash, but member lists will show "Unknown" for every member instead of real names) — and it's worse than it sounds, because for anyone who joined via `joinChoir()`, the membership doc's own stored `name` field is hardcoded to the literal string `'Member'` (not their actual name) — so the fallback isn't even a stale-but-real name, it's a generic placeholder. Member names across the app depend entirely on this now-blocked cross-read.

**I implemented the fix as requested because that's what you asked for, but I'm flagging this prominently rather than deciding for you:** you may want to hold this specific rule change until a companion app-code fix ships (recommended: stop re-fetching `users/{userId}` for other members and rely on `ChoirMembership.name` captured at join/creation time, and actually populate it with the real display name instead of the literal `'Member'`/`'Leader'` placeholders currently used in `onboarding_screen.dart` and `ChoirRepository.joinChoir`). That's an app-code change, out of scope here, but small enough to be a fast Phase 3 follow-up if you want to unblock deploying this rule immediately.

Verified by test: owner reads succeed, cross-user reads fail, unauthenticated reads fail.

---

## 3. Fix 3 — `storage.rules` choir-membership scoping

### Doc verification (done before writing any syntax)
Fetched `firebase.google.com/docs/storage/security/rules-conditions`. Confirmed:
- Cross-service Firestore access from Storage Rules uses `firestore.get(path)` / `firestore.exists(path)`.
- Path syntax: `/databases/(default)/documents/<collection>/$(docId)`.
- **Hard limit: a maximum of 2 Firestore documents may be accessed per Storage Rules evaluation.** Repeated `firestore.get()`/`firestore.exists()` calls to the *same* document path are cached within one evaluation and only count once — I designed every helper function in the new `storage.rules` to resolve to the single `choir_memberships/{choirId}_{uid}` path per request, so no rule evaluation ever exceeds 1 actual document access, well under the cap.
- This feature requires one-time IAM enablement (Firebase will prompt on first use of a rules file containing `firestore.*` calls) — flagging so you're not surprised by that prompt when you deploy.

### What changed
Previously `/audio/{choirId}/**`, `/scores/{choirId}/**`, `/chat/{choirId}/**` only checked `request.auth != null` — any signed-in user, regardless of choir membership, could read or write any choir's audio/scores/chat media. Now:

| Path | Read | Write |
|---|---|---|
| `/users/{userId}/**` | `request.auth != null` (unchanged) | own uid only (unchanged) |
| `/audio/{choirId}/**` | choir member | leader/director, **or** chorister with `'audio_uploader'` permission |
| `/scores/{choirId}/**` | choir member | leader/director, **or** chorister with `'score_librarian'` permission |
| `/chat/{choirId}/**` | choir member | choir member (any role) |

### How I chose read-only-for-members-vs-director-only-write per path — flagging where I wasn't 100% sure
- **`/audio`**: mirrored the equivalent Firestore `audio_parts` collection, whose create/update/delete rule requires `hasAnyRole(choirId, ['leader','director'])`. But I extended it to also honor the `'audio_uploader'` permission flag from `PermissionChecker.canUploadAudio`, because the app's own client-side permission model (`permission_checker.dart`) explicitly supports delegating upload rights to a chorister, and `ChoirRepository.addGuestDirector` grants exactly that permission to guest directors. **Note:** this means Storage is now slightly *more permissive* than the current `audio_parts` Firestore rule (which ignores the permission flag entirely and requires `leader`/`director` role, full stop) — I did not touch that Firestore rule since it's outside items 4–5, but it's worth knowing these two layers now disagree: a chorister with `audio_uploader` permission can upload the audio *file* to Storage but would still be rejected creating the corresponding `audio_parts` Firestore *metadata* document. Flagging this inconsistency for a future phase rather than silently "fixing" a rule I wasn't asked to touch.
- **`/scores`**: there is **no Firestore rule for score metadata at all** — no `score_attachments` (or similarly named) match block exists in `firestore.rules`; those documents currently fall through to the default deny-all. So I had nothing to mirror. I used `PermissionChecker.canManageScores` (leader/director or `'score_librarian'` permission) as the closest expression of actual app intent, since that's the real client-side gate the app already uses for this feature. Flagging clearly: **I'm not fully confident this is what you want**, since there's no existing server-side precedent to confirm against — please confirm, and separately, consider adding a `score_attachments` Firestore rule in a future phase so metadata and file storage are consistently governed.
- **`/chat`**: mirrored `chat_messages`' Firestore create rule exactly (`isTenantMember` only, no role gate) — high confidence here, direct precedent exists.

### Guest-director token expiry — why no rule was added here
The original audit item asked for a rule checking `guestTokenExpiry > request.time` "wherever guest-director write access is granted." After Fix 1, **there is no longer any such write path** — self-creating a `director`-role membership is blocked outright for everyone, guests included (see §1's flagged regression). So there's nothing left in `firestore.rules` for an expiry check to gate; adding one would be dead code. When the recommended Cloud-Function-based guest-grant is built (§1), expiry enforcement belongs *inside that function* (checked once, at grant time, using the Admin SDK before it ever writes the membership doc) rather than in client-facing rules, since Admin SDK writes aren't subject to rules anyway.

---

## 4. Emulator test results — all passing

Java (21.0.10) and the Firebase CLI (15.22.1) were both available, so I ran real tests rather than a manual checklist. Set up `@firebase/rules-unit-testing` v5 + Mocha in a scratch directory, pointed at copies of the actual rules files, and ran `firebase emulators:exec` (Firestore + Storage emulators, with Storage's Firestore cross-service calls enabled).

```
choir_memberships create — self-elevation (Fix 1)
  ✔ a chorister CANNOT self-assign role: director on create
  ✔ a user CAN self-assign role: chorister when joining a choir
  ✔ creating a choir + self-membership as leader in one batch SUCCEEDS (legitimate choir-creation flow)
  ✔ self-assigning role: leader WITHOUT actually owning the choir FAILS
  ✔ a chorister CANNOT self-elevate to director via UPDATE either (closes the update-path bypass)
  ✔ a chorister CANNOT self-grant privileged permissions via UPDATE
  ✔ an existing leader CAN promote a chorister to director via UPDATE (legitimate promotion flow preserved)
  ✔ a chorister CAN self-update a safe field (defaultVoicePart) without touching role/permissions

users/{userId} read scoping (Fix 2)
  ✔ a user CAN read their own profile
  ✔ a user CANNOT read another user's profile (closes the PII exposure)
  ✔ an unauthenticated request CANNOT read any user's profile

storage.rules choir-scoping (Fix 3)
  ✔ a non-member CANNOT read another choir's audio files
  ✔ a choir member CAN read that choir's audio files
  ✔ a chorister with no audio_uploader permission CANNOT write to /audio/{choirId}
  ✔ a director CAN write to /audio/{choirId}
  ✔ a chorister explicitly granted 'audio_uploader' CAN write to /audio/{choirId}
  ✔ any choir member CAN write to /chat/{choirId} (no role restriction, matches chat_messages rule)

17 passing (7s)
```

I did **not** write an automated test for guest-token expiry, per §3's reasoning — after Fix 1, there's no write path left to test an expiry condition against. If you want a test proving the guest-director flow now fails (documenting the regression itself, not a security property), I can add one.

Test harness files (not part of the repo, scratch-only): `firebase.json`, `rules.test.js`, `package.json` in the session scratchpad — not committed anywhere, safe to discard, or I can move them into the repo under a `firestore-tests/` directory if you'd like this suite kept for future rules changes (recommended — right now there is zero rules test coverage in the repo itself).

---

## 5. Verification checklist (per your mandatory items)

1. **Not deployed** — confirmed, working tree only.
2. **Emulator tests run and passing** — see §4 (17/17). Emulator suite was available (Java 21.0.10, Firebase CLI 15.22.1), so no manual checklist was needed.
3. **Legitimate flows traced**:
   - Leader promotes chorister → director via update: **passes**, traced through `member_detail_screen.dart` call site + test.
   - Choir creation (self-create as leader): **passes** — and I additionally fixed a separate pre-existing gap (old rule never allowed `'leader'` self-creation at all).
   - Guest-director join flow: **does NOT pass** — explicitly and intentionally, see §1. Flagged for your decision on staging/sequencing.
4. This report.

---

## 6. Summary of all rule changes

**`firestore.rules`:**
- Fixed invalid `let`-in-match-block syntax (attendance rule) — pre-existing compile-blocking bug, unrelated to the requested fixes.
- `users/{userId}` read: owner-only (was: any authenticated user).
- `choirs` create: now requires `leaderId == request.auth.uid` (was: any authenticated user, no field checks).
- `choir_memberships` create: self-serve now `chorister`-only, or `leader` gated by `getAfter()` choir-ownership proof; `director` self-creation removed entirely (was: `chorister` or `director` self-creation, unrestricted).
- `choir_memberships` update: self-updates now forbidden from changing `role`/`permissions` (was: unrestricted self-update).

**`storage.rules`:**
- `/audio`, `/scores`, `/chat` under `{choirId}` now require Firestore-verified choir membership for read; write additionally requires management role or a specific delegated permission for `/audio` and `/scores` (was: any authenticated user, no choir-scoping at all, for both read and write, on all three paths).

## 7. Open flags requiring your input before/alongside deploy
1. **Guest-director flow will break** until the recommended Cloud Function replacement ships (§1). Decide: deploy now and accept the regression, or hold the `choir_memberships` rule changes.
2. **Member names may show as "Unknown"/generic placeholders** across member list, member detail, and attendance screens until the companion app-code fix (stop live-refetching `users/{userId}` for other members) ships (§2). Same decision needed.
3. **`/scores` write permission model is my best guess** (`PermissionChecker.canManageScores`), not confirmed against an existing precedent, since no Firestore rule for score metadata exists to mirror (§3). Please confirm this is the intended model.
4. **`audio_parts` (Firestore) vs `/audio` (Storage) now disagree** on whether the `audio_uploader` permission flag is honored (§3) — Storage now allows it, Firestore metadata creation still doesn't. Not fixed (outside items 4–5), just flagged for a future phase.
5. Confirm in the Firebase console which rules are **actually currently live** in production, given §0's discovery that the committed `firestore.rules` could not have compiled successfully before this phase's fix.

Awaiting your review before Phase 3 (Payment Integrity).
