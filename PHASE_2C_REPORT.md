# Phase 2c Report — UI Cleanup

**Scope:** `member_detail_screen.dart` only, per `PHASE_2B_REPORT.md` §Fix 3 open flag #4. No rules or Cloud Functions touched, as expected — nothing here surprised or expanded scope.

---

## What changed

`kwayapro/lib/features/choir/presentation/member_detail_screen.dart`: removed the "Score Librarian" `_PermissionToggle` (label, description, and `permissionKey: 'score_librarian'`) from the "GRANT PERMISSIONS" card, along with its adjacent `Divider`, so the remaining toggles (Song Program Planner, Audio Uploader, Attendance Manager, Announcements) sit flush against each other with no leftover double-divider gap. A leader/director can no longer grant `'score_librarian'` to anyone — the control simply isn't there anymore.

## Existing production data — decided: leave it alone

Can't check production data directly, but the toggle was live and functional client-side (the `choir_memberships` update rule has always allowed a leader/director to write any field on any membership, including `permissions`, and that was never blocked at any phase) — so it's plausible some existing membership doc somewhere already has `'score_librarian'` in its `permissions` array from before this change.

**Decision: leave any such entries as-is, don't add them to the Phase 2b backfill script.** Reasoning:
- It's genuinely inert now, not misleading: nothing in `storage.rules` or any UI acts on `'score_librarian'` for an authorization decision anymore (Phase 2b removed the Storage delegation; there was never a scores-upload screen to gate in the first place).
- The Phase 2b backfill script fixes *wrong* data (placeholder names actively degrading the member-list UI). A leftover `'score_librarian'` flag isn't wrong — it accurately records that a leader granted it at the time, and its presence doesn't degrade anything since nothing reads it for authorization anymore.
- If a real scores-upload feature ships later and the Storage delegation is reinstated, these legacy grants being intact is actually the *correct* end state — it retroactively honors what those leaders originally intended. There'd be nothing to "clean up" in that scenario.
- Bundling this into the names-backfill script would conflate two unrelated cleanup concerns (identity data vs. a permission flag) in one already-narrowly-scoped tool, which just makes it harder to review.

## `permission_checker.dart` — checked, no change needed

`canManageScores` (`isManagement || _has('score_librarian')`) still references `'score_librarian'`. Left as-is, deliberately: this is a passive read of whatever's in `membership.permissions`, not a grant mechanism — it doesn't need to "know" the toggle was removed. If a legacy membership still has the flag, `canManageScores` correctly still returns `true` for that one member (harmless, matches the "leave stale entries alone" decision above); for everyone else, it now only ever resolves via `isManagement`. No dangling reference to a removed method or constant — nothing to update here.

## One related display path, intentionally left untouched

`members_screen.dart`'s `_getPermissionLabel()` switch still maps `'score_librarian' => 'Scores'`. This isn't a grant control, it's a *display* label used when rendering chips for whatever permissions a member's document already lists (`members_screen.dart:196`). Removing this mapping would make any pre-existing `'score_librarian'` entry render as the raw string `"score_librarian"` instead of a clean "Scores" chip — a pure display regression for zero benefit, since the entry itself is being deliberately left in place per the decision above. Kept as-is.

## Verification
`flutter analyze` — clean, no issues, both before and after (ran twice to confirm the diff didn't introduce anything).

No other flags surfaced. Awaiting your review before deploying Phase 2 + 2b + 2c together, then before Phase 3.
