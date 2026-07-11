# Phase 1 Report — Deploy Safety & Secrets

**Scope:** PRODUCTION_READINESS_AUDIT.md action items 1–3 only. No security rules content, payment code, or other sections were touched.

---

## Investigation (before any changes)

- `.firebaserc` exists **only at repo root** (`{"projects":{"default":"kwayapro-app"}}`). No `.firebaserc` exists anywhere under `kwayapro/`.
- Root `firebase.json` is a complete, standalone deploy config: `storage.rules` → root `storage.rules`, `firestore.rules`/`firestore.indexes.json` → root files, plus the `functions` codebase.
- `kwayapro/firebase.json` is FlutterFire-CLI-generated (it has a `"flutter"` key, which is FlutterFire tooling config, not a Firebase CLI deploy key) and also carried stale `"firestore"`/`"storage"` stanzas pointing at files that no longer exist locally.
- No README (root or `kwayapro/`) documents a deploy procedure or references `set_secrets.js`.
- **Conclusion: the root directory is the only valid `firebase deploy` anchor** — the Firebase CLI needs `.firebaserc` (or an explicit `--project` flag) to know which project to target, and that file only exists at root. Running `firebase deploy` from `kwayapro/` would fail to resolve a project at all; it was never a viable second deploy path, just a dangling config that could confuse a future contributor.

---

## Changes made

### Fix 1 — `kwayapro/firebase.json` dangling reference
**Chose:** delete the `"firestore"` and `"storage"` stanzas rather than repoint them, since `kwayapro/firebase.json` has no `.firebaserc` and isn't a real deploy entry point — repointing it would preserve a misleading impression that it's a second valid deploy config. It now contains only the `"flutter"` block, which is what FlutterFire tooling (`flutterfire configure`) actually reads/writes.

### Fix 2 — `storage.rules` consolidation
- Root `storage.rules` replaced with the working ruleset previously at `kwayapro/storage.rules` (per-user avatar access under `/users/{userId}/**`, plus `/audio/{choirId}/**`, `/scores/{choirId}/**`, `/chat/{choirId}/**` — all auth-gated).
- `kwayapro/storage.rules` deleted (redundant now; root is single source of truth, consistent with the firestore.rules consolidation already done previously).

**Final root `storage.rules` (for manual review before any deploy):**
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // User avatars — own only
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // Audio parts — choir members read, directors/uploaders write
    match /audio/{choirId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Scores — choir members read, score librarians write
    match /scores/{choirId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Chat media — choir members
    match /chat/{choirId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```
Note: this ruleset only checks `request.auth != null` for `/audio`, `/scores`, `/chat` writes — it does not verify the requester is actually a member of `{choirId}`. That's a real gap, but it's a **security-rules-content** issue, explicitly out of scope for this phase per your instructions — flagging it here so it lands correctly in Phase 2 rather than being silently fixed or silently missed.

### Fix 3 — `set_secrets.js` exposure
1. Added to `.gitignore` (defense in depth, even though it was already untracked):
   ```
   # Local secret-setting scripts (contain plaintext credential values — never commit)
   set_secrets.js
   ```
2. Moved the file out of the repo to `~/kwayapro-secrets/set_secrets.js` (i.e. `C:\Users\SPK\kwayapro-secrets\set_secrets.js`). No README referenced its old repo-root location, so no docs needed updating.
3. **Git history check — clean.** Ran:
   - `git log --all --full-history -- set_secrets.js` → no results (file was never committed under this name).
   - `git log --all --diff-filter=A --name-only | grep -i secret` → no results (no file matching "secret" was ever added in any commit, on any branch).
   - `git log --all -p -S "<literal MTN_API_KEY value>"` and `-S "<literal R2_ACCESS_KEY_ID value>"` → no results (the literal secret values never appear in any diff across history).
   - The only place `MTN_API_KEY` etc. appear in git history is as **secret *names*** passed to `defineSecret("MTN_API_KEY")` in `functions/src/index.ts` (committed in `23bbe28`) — this is expected and safe; it's a reference to a Secret Manager key name, not a value.
   - **Conclusion: `set_secrets.js` and its contents have never been committed to this repository, in any commit or branch.** This lowers urgency somewhat (no need to scrub git history / force-push), but the file held live-looking values on disk in a repo working directory with no `.gitignore` protection — rotation is still strongly recommended as a precaution, since "never committed" doesn't rule out other exposure paths (shared machine, backup tooling, etc.).
4. **Secret key names requiring your manual review/rotation** (values not reproduced here):
   - `MTN_API_USER`
   - `MTN_API_KEY`
   - `MTN_SUBSCRIPTION_KEY`
   - `MTN_WEBHOOK_SECRET`
   - `MTN_TARGET_ENV` *(not sensitive — value was `"sandbox"`, informational only)*
   - `R2_ACCOUNT_ID`
   - `R2_ACCESS_KEY_ID`
   - `R2_SECRET_ACCESS_KEY`
   - `R2_BUCKET_NAME` *(not sensitive — a bucket name)*
   - `R2_PUBLIC_URL` *(not sensitive — a public URL)*

   The genuinely sensitive ones to consider rotating in the MTN and Cloudflare dashboards: **`MTN_API_KEY`, `MTN_SUBSCRIPTION_KEY`, `MTN_WEBHOOK_SECRET`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`**.

---

## Verification

1. **`flutter analyze`** (run from `kwayapro/`): `No issues found! (ran in 111.4s)` — clean.
2. **No remaining references to the old `set_secrets.js` path** anywhere in the repo — confirmed via a full-repo case-insensitive search; the only hits are the new `.gitignore` entry (expected) and mentions inside `PRODUCTION_READINESS_AUDIT.md` (a historical audit record, not a functional reference).
3. **Deploy path traced end-to-end:** `.firebaserc` exists only at repo root → `firebase deploy` must be run from the repo root to resolve a project at all → it will read root `firebase.json`, which points to:
   - `storage.rules` → root `storage.rules` (now the working per-path ruleset, **not** deny-all)
   - `firestore.rules` → root `firestore.rules` (unchanged this phase — the `hasAnyRole()` version, already the sole surviving copy from the prior consolidation)
   - `firestore.indexes.json` → root (unchanged this phase)
   - `functions/` → the Cloud Functions codebase (unchanged this phase)

   `kwayapro/firebase.json` no longer references any rules/index files at all, so it cannot be a source of stale/dangling deploys even if someone mistakenly ran a Firebase CLI command from that directory (it would fail to resolve a project, since it also has no `.firebaserc`).

**Confirmed: a `firebase deploy` run today from the repo root would deploy the correct, working `storage.rules` (not deny-all) and the correct, already-consolidated `firestore.rules`.**

---

## Files changed this phase
- `kwayapro/firebase.json` — removed dangling `firestore`/`storage` stanzas
- `storage.rules` (root) — replaced deny-all content with the working ruleset
- `kwayapro/storage.rules` — deleted (consolidated to root)
- `.gitignore` — added `set_secrets.js`
- `set_secrets.js` — moved from repo root to `~/kwayapro-secrets/set_secrets.js` (outside version control)

## Explicitly not touched (per scope)
- `firestore.rules` content (including the `choir_memberships` self-elevation and `users/{userId}` PII-exposure findings)
- The new storage-rules gap noted above (choir-membership not verified for `/audio`, `/scores`, `/chat`)
- Any payment/webhook code
- `set_airtel_secrets.js` (contains only placeholder `'dummy'` values per the original audit — not in scope for this phase)

Awaiting review before Phase 2.
