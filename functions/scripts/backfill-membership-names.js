/**
 * One-time backfill: replaces placeholder choir_memberships.name values
 * ('Member', 'Leader', 'Guest Director', 'Unknown Member' — see
 * PHASE_2B_REPORT.md Fix 2) with each member's real display name from their
 * users/{userId} document.
 *
 * NOT run automatically and NOT wired into any deploy step. Run it once,
 * manually, after Phase 2 + 2b are deployed:
 *
 *   cd functions
 *   npm install firebase-admin   # if not already present
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json \
 *     node scripts/backfill-membership-names.js
 *
 * Requires a service account key with Firestore read/write access to the
 * target project (Firebase Console → Project Settings → Service Accounts →
 * Generate new private key). Do not commit that key file to the repo.
 *
 * Safe to re-run: only updates docs whose current name matches a known
 * placeholder AND differs from the user's real stored name. Dry-run first
 * with --dry-run to see what would change without writing anything.
 */

const admin = require("firebase-admin");

const DRY_RUN = process.argv.includes("--dry-run");
const PLACEHOLDER_NAMES = new Set(["Member", "Leader", "Guest Director", "Unknown Member", ""]);

admin.initializeApp();
const db = admin.firestore();

async function main() {
  const membershipsSnap = await db.collection("choir_memberships").get();
  console.log(`Scanning ${membershipsSnap.size} choir_memberships document(s)...`);

  let checked = 0;
  let toUpdate = 0;
  let updated = 0;
  let skippedNoUser = 0;

  const userCache = new Map();

  for (const doc of membershipsSnap.docs) {
    checked++;
    const data = doc.data();
    const currentName = (data.name || "").trim();
    if (!PLACEHOLDER_NAMES.has(currentName)) continue;

    const userId = data.userId;
    if (!userId) continue;

    let userData = userCache.get(userId);
    if (userData === undefined) {
      const userSnap = await db.collection("users").doc(userId).get();
      userData = userSnap.exists ? userSnap.data() : null;
      userCache.set(userId, userData);
    }

    const realName = (userData && userData.name || "").trim();
    if (!realName || realName === currentName) {
      skippedNoUser++;
      continue;
    }

    toUpdate++;
    console.log(
      `${DRY_RUN ? "[dry-run] would update" : "updating"} ${doc.id}: "${currentName}" -> "${realName}"`
    );
    if (!DRY_RUN) {
      await doc.ref.update({ name: realName });
      updated++;
    }
  }

  console.log("---");
  console.log(`Checked: ${checked}`);
  console.log(`Had a placeholder name with a real name available: ${toUpdate}`);
  console.log(`Skipped (no user doc / no real name on file): ${skippedNoUser}`);
  if (DRY_RUN) {
    console.log("Dry run only — no writes performed. Re-run without --dry-run to apply.");
  } else {
    console.log(`Updated: ${updated}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Backfill failed:", err);
    process.exit(1);
  });
