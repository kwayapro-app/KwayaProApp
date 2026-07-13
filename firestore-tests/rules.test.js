const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

before(async function () {
  this.timeout(60000);
  testEnv = await initializeTestEnvironment({
    projectId: "kwayapro-rules-test",
    firestore: {
      // Tests the ACTUAL repo-root firestore.rules/storage.rules directly —
      // not a copy — so this suite can never silently drift from what would
      // really be deployed. See PHASE_7_REPORT.md.
      rules: fs.readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8180,
    },
    storage: {
      rules: fs.readFileSync("../storage.rules", "utf8"),
      host: "127.0.0.1",
      port: 9299,
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

describe("choir_memberships create — self-elevation (Fix 1)", () => {
  it("a chorister CANNOT self-assign role: director on create", async () => {
    const alice = testEnv.authenticatedContext("alice");
    const db = alice.firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_alice").set({
        choirId: "choirA",
        userId: "alice",
        role: "director",
        defaultVoicePart: "S",
        permissions: [],
        joinedAt: new Date(),
      })
    );
  });

  it("a user CAN self-assign role: chorister when joining a choir", async () => {
    const bob = testEnv.authenticatedContext("bob");
    const db = bob.firestore();
    await assertSucceeds(
      db.collection("choir_memberships").doc("choirA_bob").set({
        choirId: "choirA",
        userId: "bob",
        role: "chorister",
        defaultVoicePart: "A",
        permissions: [],
        joinedAt: new Date(),
      })
    );
  });

  it("creating a choir + self-membership as leader in one batch SUCCEEDS (legitimate choir-creation flow)", async () => {
    const carol = testEnv.authenticatedContext("carol");
    const db = carol.firestore();
    const batch = db.batch();
    batch.set(db.collection("choirs").doc("choirC"), {
      choirId: "choirC",
      name: "Test Choir",
      churchName: "Test Church",
      leaderId: "carol",
      inviteCode: "ABC123",
      plan: "free",
      songCount: 0,
      createdAt: new Date(),
    });
    batch.set(db.collection("choir_memberships").doc("choirC_carol"), {
      choirId: "choirC",
      userId: "carol",
      role: "leader",
      defaultVoicePart: "S",
      permissions: [],
      joinedAt: new Date(),
    });
    await assertSucceeds(batch.commit());
  });

  it("self-assigning role: leader WITHOUT actually owning the choir FAILS", async () => {
    const mallory = testEnv.authenticatedContext("mallory");
    const db = mallory.firestore();
    const batch = db.batch();
    // choir's leaderId is someone else — mallory should not be able to
    // self-grant herself 'leader' on it.
    batch.set(db.collection("choirs").doc("choirD"), {
      choirId: "choirD",
      name: "Someone Else's Choir",
      churchName: "Test Church",
      leaderId: "someone-else",
      inviteCode: "XYZ999",
      plan: "free",
      songCount: 0,
      createdAt: new Date(),
    });
    batch.set(db.collection("choir_memberships").doc("choirD_mallory"), {
      choirId: "choirD",
      userId: "mallory",
      role: "leader",
      defaultVoicePart: "S",
      permissions: [],
      joinedAt: new Date(),
    });
    await assertFails(batch.commit());
  });

  it("a chorister CANNOT self-elevate to director via UPDATE either (closes the update-path bypass)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_dave").set({
        choirId: "choirA",
        userId: "dave",
        role: "chorister",
        defaultVoicePart: "T",
        permissions: [],
        joinedAt: new Date(),
      });
    });
    const dave = testEnv.authenticatedContext("dave");
    const db = dave.firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_dave").update({
        role: "director",
      })
    );
  });

  it("a chorister CANNOT self-grant privileged permissions via UPDATE", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_erin").set({
        choirId: "choirA",
        userId: "erin",
        role: "chorister",
        defaultVoicePart: "B",
        permissions: [],
        joinedAt: new Date(),
      });
    });
    const erin = testEnv.authenticatedContext("erin");
    const db = erin.firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_erin").update({
        permissions: ["audio_uploader"],
      })
    );
  });

  // SECURITY FIX (Leader/Director audit, Finding #3): confirmed live via the
  // emulator that this "legitimate promotion flow" was actually exploitable
  // by ANY director, not just the Leader, with no restriction on which
  // fields changed — a director could update their OWN doc to role:
  // 'leader', or grant a different member's doc arbitrary permissions/role.
  // `role` is now immutable through this client-facing rule entirely; every
  // real role transition goes through the create rule or an Admin SDK Cloud
  // Function (see functions/src/index.ts). This test now asserts the
  // closed hole directly; the real replacement flow is covered by the
  // "onRehearsalSessionDirectorChanged" test in the Director Session
  // Scoping suite below.
  it("even the LEADER CANNOT change a member's role via client UPDATE anymore (role changes only via Cloud Functions)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_leader1").set({
        choirId: "choirA",
        userId: "leader1",
        role: "leader",
        defaultVoicePart: "S",
        permissions: [],
        joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("choirA_frank").set({
        choirId: "choirA",
        userId: "frank",
        role: "chorister",
        defaultVoicePart: "T",
        permissions: [],
        joinedAt: new Date(),
      });
    });
    const leader1 = testEnv.authenticatedContext("leader1");
    const db = leader1.firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_frank").update({
        role: "director",
      })
    );
  });

  it("the LEADER CAN still grant/revoke another member's granular permissions and change their default voice part", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_leader2").set({
        choirId: "choirA", userId: "leader2", role: "leader",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("choirA_gina").set({
        choirId: "choirA", userId: "gina", role: "chorister",
        defaultVoicePart: "T", permissions: [], joinedAt: new Date(),
      });
    });
    const leader2 = testEnv.authenticatedContext("leader2");
    const db = leader2.firestore();
    await assertSucceeds(
      db.collection("choir_memberships").doc("choirA_gina").update({
        permissions: ["attendance_manager"],
      })
    );
    await assertSucceeds(
      db.collection("choir_memberships").doc("choirA_gina").update({
        defaultVoicePart: "B",
      })
    );
  });

  it("a DIRECTOR (not the Leader) CANNOT self-escalate to leader, or grant another member's permissions/role (closes the live-confirmed hole)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_dave").set({
        choirId: "choirA", userId: "dave", role: "director",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("choirA_hank").set({
        choirId: "choirA", userId: "hank", role: "chorister",
        defaultVoicePart: "T", permissions: [], joinedAt: new Date(),
      });
    });
    const dave = testEnv.authenticatedContext("dave");
    const db = dave.firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_dave").update({ role: "leader" })
    );
    await assertFails(
      db.collection("choir_memberships").doc("choirA_hank").update({ permissions: ["announcements"] })
    );
    await assertFails(
      db.collection("choir_memberships").doc("choirA_hank").update({ role: "leader" })
    );
  });

  it("a director CANNOT tamper with their own directorPriorRole (would otherwise let them get 'restored' as leader on their own expiry)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc("choirA_ivan").set({
        choirId: "choirA", userId: "ivan", role: "director",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
        directorSessionId: "someSession", directorPriorRole: "chorister", directorPriorPermissions: [],
      });
    });
    const db = testEnv.authenticatedContext("ivan").firestore();
    await assertFails(
      db.collection("choir_memberships").doc("choirA_ivan").update({ directorPriorRole: "leader" })
    );
  });

  it("a chorister CAN self-update a safe field (defaultVoicePart) without touching role/permissions", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choir_memberships").doc("choirA_grace").set({
        choirId: "choirA",
        userId: "grace",
        role: "chorister",
        defaultVoicePart: "A",
        permissions: [],
        joinedAt: new Date(),
      });
    });
    const grace = testEnv.authenticatedContext("grace");
    const db = grace.firestore();
    await assertSucceeds(
      db.collection("choir_memberships").doc("choirA_grace").update({
        defaultVoicePart: "S",
        role: "chorister",
        permissions: [],
      })
    );
  });
});

describe("users/{userId} read scoping (Fix 2)", () => {
  it("a user CAN read their own profile", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("alice").set({
        userId: "alice", name: "Alice", phone: "+256700000001",
      });
    });
    await assertSucceeds(alice.firestore().collection("users").doc("alice").get());
  });

  it("a user CANNOT read another user's profile (closes the PII exposure)", async () => {
    const alice = testEnv.authenticatedContext("alice");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("bob").set({
        userId: "bob", name: "Bob", phone: "+256700000002",
      });
    });
    await assertFails(alice.firestore().collection("users").doc("bob").get());
  });

  it("an unauthenticated request CANNOT read any user's profile", async () => {
    const anon = testEnv.unauthenticatedContext();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("bob").set({
        userId: "bob", name: "Bob", phone: "+256700000002",
      });
    });
    await assertFails(anon.firestore().collection("users").doc("bob").get());
  });
});

describe("storage.rules choir-scoping (Fix 3)", () => {
  async function seedMembership(choirId, uid, role, permissions) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc(`${choirId}_${uid}`).set({
        choirId, userId: uid, role, defaultVoicePart: "S", permissions: permissions || [], joinedAt: new Date(),
      });
    });
  }

  it("a non-member CANNOT read another choir's audio files", async () => {
    await seedMembership("choirA", "member1", "chorister");
    const outsider = testEnv.authenticatedContext("outsider");
    const storage = outsider.storage();
    await assertFails(
      storage.ref("audio/choirA/song1/S.m4a").getDownloadURL()
    );
  });

  it("a choir member CAN read that choir's audio files", async () => {
    await seedMembership("choirA", "member1", "chorister");
    // seed a fake object isn't trivial via rules-unit-testing without admin upload;
    // instead assert the rule permits the read attempt (metadata read used as proxy)
    const member = testEnv.authenticatedContext("member1");
    const storage = member.storage();
    await assertSucceeds(
      storage.ref("audio/choirA/song1/S.m4a").getMetadata().catch((e) => {
        // object-not-found is fine — proves the rule allowed the request through
        // to Storage's object layer rather than denying at the rules layer.
        if (e.code === "storage/object-not-found") return Promise.resolve();
        throw e;
      })
    );
  });

  it("a chorister with no audio_uploader permission CANNOT write to /audio/{choirId}", async () => {
    await seedMembership("choirB", "chorister1", "chorister");
    const chorister = testEnv.authenticatedContext("chorister1");
    const storage = chorister.storage();
    await assertFails(
      storage.ref("audio/choirB/song1/S.m4a").putString("fake-audio-bytes")
    );
  });

  it("a director CAN write to /audio/{choirId}", async () => {
    await seedMembership("choirB", "director1", "director");
    const director = testEnv.authenticatedContext("director1");
    const storage = director.storage();
    await assertSucceeds(
      storage.ref("audio/choirB/song1/S.m4a").putString("fake-audio-bytes")
    );
  });

  it("a chorister explicitly granted 'audio_uploader' CAN write to /audio/{choirId}", async () => {
    await seedMembership("choirB", "chorister2", "chorister", ["audio_uploader"]);
    const chorister = testEnv.authenticatedContext("chorister2");
    const storage = chorister.storage();
    await assertSucceeds(
      storage.ref("audio/choirB/song2/S.m4a").putString("fake-audio-bytes")
    );
  });

  it("any choir member CAN write to /chat/{choirId} (no role restriction, matches chat_messages rule)", async () => {
    await seedMembership("choirC", "chatter1", "chorister");
    const chatter = testEnv.authenticatedContext("chatter1");
    const storage = chatter.storage();
    await assertSucceeds(
      storage.ref("chat/choirC/img1.jpg").putString("fake-image-bytes")
    );
  });

  // FUNCTIONAL FIX (Leader/Director audit, Finding #5): score_attachments
  // now has a matching Firestore rule with the same role-or-permission
  // shape as canUploadAudio, so this delegation is no longer the odd one
  // out — flipped from the Phase 2b "delegation removed" assertion.
  it("a chorister with 'score_librarian' permission CAN now write to /scores (delegation added — Finding #5)", async () => {
    await seedMembership("choirD", "librarian1", "chorister", ["score_librarian"]);
    const chorister = testEnv.authenticatedContext("librarian1");
    const storage = chorister.storage();
    await assertSucceeds(
      storage.ref("scores/choirD/song1/lead.pdf").putString("fake-pdf-bytes")
    );
  });

  it("a director CAN write to /scores (leader/director only, no delegation)", async () => {
    await seedMembership("choirD", "director2", "director");
    const director = testEnv.authenticatedContext("director2");
    const storage = director.storage();
    await assertSucceeds(
      storage.ref("scores/choirD/song1/lead.pdf").putString("fake-pdf-bytes")
    );
  });

  it("a plain chorister (no permission) CANNOT write to /scores", async () => {
    await seedMembership("choirD", "chorister3", "chorister");
    const chorister = testEnv.authenticatedContext("chorister3");
    const storage = chorister.storage();
    await assertFails(
      storage.ref("scores/choirD/song1/lead.pdf").putString("fake-pdf-bytes")
    );
  });
});

describe("songs create — server-side freemium cap (Phase 3 Fix 5)", () => {
  async function seedChoirAndDirector(choirId, uid, { plan, songCount }) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choirs").doc(choirId).set({
        choirId, name: "Test Choir", churchName: "Test Church", leaderId: "someone-else",
        inviteCode: "CAP123", plan, songCount, createdAt: new Date(),
      });
      await db.collection("choir_memberships").doc(`${choirId}_${uid}`).set({
        choirId, userId: uid, role: "director", defaultVoicePart: "S",
        permissions: [], joinedAt: new Date(),
      });
    });
  }

  it("a free-plan choir under the cap (songCount 2) CAN create a song", async () => {
    await seedChoirAndDirector("choirFree1", "director1", { plan: "free", songCount: 2 });
    const director = testEnv.authenticatedContext("director1");
    const db = director.firestore();
    await assertSucceeds(
      db.collection("songs").doc().set({
        songId: "s1", choirId: "choirFree1", title: "Song 1", key: "C", language: "en",
        category: "hymn", uploadedBy: "director1", createdAt: new Date(),
      })
    );
  });

  it("a free-plan choir AT the cap (songCount 3) CANNOT create a 4th song directly via Firestore", async () => {
    await seedChoirAndDirector("choirFree2", "director2", { plan: "free", songCount: 3 });
    const director = testEnv.authenticatedContext("director2");
    const db = director.firestore();
    await assertFails(
      db.collection("songs").doc().set({
        songId: "s2", choirId: "choirFree2", title: "Song 4", key: "C", language: "en",
        category: "hymn", uploadedBy: "director2", createdAt: new Date(),
      })
    );
  });

  it("a pro-plan choir at/above songCount 3 CAN still create songs (no cap)", async () => {
    await seedChoirAndDirector("choirPro1", "director3", { plan: "pro", songCount: 12 });
    const director = testEnv.authenticatedContext("director3");
    const db = director.firestore();
    await assertSucceeds(
      db.collection("songs").doc().set({
        songId: "s3", choirId: "choirPro1", title: "Song 13", key: "C", language: "en",
        category: "hymn", uploadedBy: "director3", createdAt: new Date(),
      })
    );
  });

  it("Phase 3b: a freshly-downgraded choir over the cap keeps ALL existing songs readable (no crash/silent breakage)", async () => {
    // Simulates the post-cancelSubscription state: plan flipped to 'free'
    // but songCount left untouched at its pre-downgrade value (7, matching
    // the cancelSubscription integration test) — existing song docs are
    // never deleted or hidden by the downgrade.
    await seedChoirAndDirector("choirDowngraded1", "director4", { plan: "free", songCount: 7 });
    const director = testEnv.authenticatedContext("director4");
    const db = director.firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const adminDb = ctx.firestore();
      for (let i = 1; i <= 7; i++) {
        await adminDb.collection("songs").doc(`existing-song-${i}`).set({
          songId: `existing-song-${i}`, choirId: "choirDowngraded1", title: `Song ${i}`,
          key: "C", language: "en", category: "hymn", uploadedBy: "director4", createdAt: new Date(),
        });
      }
    });

    const snap = await db.collection("songs").where("choirId", "==", "choirDowngraded1").get();
    if (snap.size !== 7) throw new Error(`expected 7 readable songs, got ${snap.size}`);
    await assertSucceeds(
      db.collection("songs").where("choirId", "==", "choirDowngraded1").get()
    );

    // ...but creating an 8th (a NEW song, above the now-applicable Free cap)
    // is correctly blocked.
    await assertFails(
      db.collection("songs").doc("existing-song-8").set({
        songId: "existing-song-8", choirId: "choirDowngraded1", title: "Song 8",
        key: "C", language: "en", category: "hymn", uploadedBy: "director4", createdAt: new Date(),
      })
    );
  });
});

describe("Phase 4 Fix 3: concurrent song-create transactions against the REAL emulator", () => {
  // fake_cloud_firestore's runTransaction (used in the Dart unit tests) is a
  // single-shot pass-through with no real optimistic-concurrency/contention
  // behavior, so it can't exercise an actual race between two simultaneous
  // transactions. This test validates the underlying mechanism SongRepository
  // .createSong relies on, directly against the real Firestore emulator (the
  // same one enforcing the actual deployed Fix 5 rule): read
  // choirs/{choirId}.songCount + a limit check + a song create + a songCount
  // increment, all inside one runTransaction — the exact shape of the Dart
  // transaction, executed via the JS client SDK so genuine transaction
  // contention/retry applies.
  it("two concurrent create-transactions at songCount==2 for a free choir: exactly one succeeds", async () => {
    await seedForRaceTest("raceChoir1", "raceDirector1", 2);
    const director = testEnv.authenticatedContext("raceDirector1");
    const db = director.firestore();

    const attempt = (songId) => db.runTransaction(async (tx) => {
      const choirRef = db.collection("choirs").doc("raceChoir1");
      const choirSnap = await tx.get(choirRef);
      const choir = choirSnap.data();
      if (choir.plan === "free" && choir.songCount >= 3) {
        throw new Error("SongLimitExceededException");
      }
      const songRef = db.collection("songs").doc(songId);
      tx.set(songRef, {
        songId, choirId: "raceChoir1", title: `Song ${songId}`, key: "C",
        language: "en", category: "hymn", uploadedBy: "raceDirector1", createdAt: new Date(),
      });
      tx.update(choirRef, { songCount: choir.songCount + 1 });
    });

    const results = await Promise.allSettled([attempt("raceSongA"), attempt("raceSongB")]);
    const succeeded = results.filter((r) => r.status === "fulfilled");
    const failed = results.filter((r) => r.status === "rejected");

    check("exactly one of the two concurrent transactions succeeded", succeeded.length === 1, results);
    check("exactly one of the two concurrent transactions was rejected", failed.length === 1, results);

    const choirSnap = await db.collection("choirs").doc("raceChoir1").get();
    check(
      "songCount ended at exactly 3, not 4 (no double-increment)",
      choirSnap.data().songCount === 3,
      choirSnap.data()
    );
  });

  async function seedForRaceTest(choirId, uid, songCount) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choirs").doc(choirId).set({
        choirId, name: "Race Choir", churchName: "Test Church", leaderId: uid,
        inviteCode: "RACE12", plan: "free", songCount, createdAt: new Date(),
      });
      await db.collection("choir_memberships").doc(`${choirId}_${uid}`).set({
        choirId, userId: uid, role: "director", defaultVoicePart: "S",
        permissions: [], joinedAt: new Date(),
      });
    });
  }

  function check(label, cond, extra) {
    if (!cond) {
      throw new Error(`FAILED: ${label} -- ${JSON.stringify(extra)}`);
    }
    console.log(`  ✔ ${label}`);
  }
});

// Leader/Director audit (Findings #1, #2, #4): director access must be
// scoped to directorSessionId, not choir-wide, and expiry must actually
// revoke it server-side. joinAsGuestDirector/onRehearsalSessionDirectorChanged
// /checkGuestTokenExpiry live in functions/src/index.ts (Admin SDK, bypasses
// these rules) — these tests exercise the rules layer directly by seeding
// the exact document shape those functions produce, the same way the rest
// of this suite already does for other server-driven flows.
describe("Director session scoping (Leader/Director audit Findings #1, #2)", () => {
  async function seedSessionDirector(choirId, sessionId, uid, opts = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choirs").doc(choirId).set({
        choirId, name: "Scoped Choir", churchName: "Test", leaderId: `${uid}_leader`,
        inviteCode: `INV_${choirId}`, plan: "free", songCount: 0, createdAt: new Date(),
      });
      await db.collection("rehearsal_sessions").doc(sessionId).set({
        sessionId, choirId, date: new Date(), time: "10:00", location: "",
        directorId: uid, isGuestDirector: !!opts.isGuest, notes: null,
      });
      await db.collection("choir_memberships").doc(`${choirId}_${uid}`).set({
        choirId, userId: uid, role: "director", defaultVoicePart: "S",
        permissions: [], joinedAt: new Date(),
        directorSessionId: sessionId,
        directorPriorRole: "chorister",
        directorPriorPermissions: [],
      });
    });
  }

  it("a session-scoped director CAN update their OWN assigned session", async () => {
    await seedSessionDirector("scopeChoirA", "scopeSessionA", "dirA");
    const db = testEnv.authenticatedContext("dirA").firestore();
    await assertSucceeds(
      db.collection("rehearsal_sessions").doc("scopeSessionA").update({ notes: "updated" })
    );
  });

  it("a session-scoped director CANNOT update a DIFFERENT session in the same choir (closes the live-confirmed choir-wide leak)", async () => {
    await seedSessionDirector("scopeChoirB", "scopeSessionB1", "dirB");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("rehearsal_sessions").doc("scopeSessionB2").set({
        sessionId: "scopeSessionB2", choirId: "scopeChoirB", date: new Date(),
        time: "10:00", location: "", directorId: "someoneElse", isGuestDirector: false, notes: null,
      });
    });
    const db = testEnv.authenticatedContext("dirB").firestore();
    await assertFails(
      db.collection("rehearsal_sessions").doc("scopeSessionB2").update({ notes: "hijacked" })
    );
  });

  it("a director CANNOT create a brand new rehearsal session (Leader-only)", async () => {
    await seedSessionDirector("scopeChoirC", "scopeSessionC", "dirC");
    const db = testEnv.authenticatedContext("dirC").firestore();
    await assertFails(
      db.collection("rehearsal_sessions").doc("scopeSessionCNew").set({
        sessionId: "scopeSessionCNew", choirId: "scopeChoirC", date: new Date(),
        time: "10:00", location: "", directorId: "dirC", isGuestDirector: false, notes: null,
      })
    );
  });

  it("a session-scoped director CAN mark attendance for their OWN session", async () => {
    await seedSessionDirector("scopeChoirD", "scopeSessionD", "dirD");
    const db = testEnv.authenticatedContext("dirD").firestore();
    await assertSucceeds(
      db.collection("attendance").doc("scopeSessionD_someMember").set({
        sessionId: "scopeSessionD", userId: "someMember", choirId: "scopeChoirD", attended: true,
      })
    );
  });

  it("a session-scoped director CANNOT mark attendance for a DIFFERENT session (closes the live-confirmed choir-wide leak)", async () => {
    await seedSessionDirector("scopeChoirE", "scopeSessionE1", "dirE");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("rehearsal_sessions").doc("scopeSessionE2").set({
        sessionId: "scopeSessionE2", choirId: "scopeChoirE", date: new Date(),
        time: "10:00", location: "", directorId: "someoneElse", isGuestDirector: false, notes: null,
      });
    });
    const db = testEnv.authenticatedContext("dirE").firestore();
    await assertFails(
      db.collection("attendance").doc("scopeSessionE2_someMember").set({
        sessionId: "scopeSessionE2", userId: "someMember", choirId: "scopeChoirE", attended: true,
      })
    );
  });

  it("a director (incl. guest) CANNOT edit the choir profile (closes the live-confirmed admin-settings leak)", async () => {
    await seedSessionDirector("scopeChoirF", "scopeSessionF", "dirF", { isGuest: true });
    const db = testEnv.authenticatedContext("dirF").firestore();
    await assertFails(
      db.collection("choirs").doc("scopeChoirF").update({ name: "Renamed by guest" })
    );
  });

  it("a director's songCount increment (part of the song-upload transaction) still works despite the choirs-update lockdown", async () => {
    await seedSessionDirector("scopeChoirG", "scopeSessionG", "dirG");
    const db = testEnv.authenticatedContext("dirG").firestore();
    await assertSucceeds(
      db.collection("choirs").doc("scopeChoirG").update({ songCount: 1 })
    );
  });

  it("after a simulated expiry (membership reverted to its prior role), the ex-director loses all director rights", async () => {
    await seedSessionDirector("scopeChoirH", "scopeSessionH", "dirH");
    // Simulates exactly what checkGuestTokenExpiry's revokeDirectorGrant
    // does: restore directorPriorRole/directorPriorPermissions and clear
    // the director-grant bookkeeping fields (a full overwrite here rather
    // than FieldValue.delete() sentinels, but the same end state: those
    // fields are simply absent afterward).
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc("scopeChoirH_dirH").set({
        choirId: "scopeChoirH", userId: "dirH", role: "chorister",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext("dirH").firestore();
    await assertFails(
      db.collection("attendance").doc("scopeSessionH_someMember").set({
        sessionId: "scopeSessionH", userId: "someMember", choirId: "scopeChoirH", attended: true,
      })
    );
    await assertFails(
      db.collection("rehearsal_sessions").doc("scopeSessionH").update({ notes: "should fail now" })
    );
  });
});

// Leader/Director audit (Finding #4): assigning an existing member as a
// rehearsal's director via rehearsals_screen.dart's picker used to only set
// a cosmetic directorId field, granting zero actual capability. This
// exercises the REAL onRehearsalSessionDirectorChanged Firestore trigger
// (functions/src/index.ts), not just the rules layer, since the trigger is
// what's supposed to turn that assignment into a real grant.
describe("onRehearsalSessionDirectorChanged trigger (Leader/Director audit Finding #4)", () => {
  // The emulator's Firestore-trigger dispatch is noticeably slower than the
  // writes themselves (observed several seconds of latency, well past a
  // typical assertSucceeds/assertFails round trip) — this polls generously
  // rather than assuming near-instant delivery. Reads via `readerUid`'s own
  // authenticated context (a tenant member of the choir, so the
  // choir_memberships read rule's isTenantMember branch already allows
  // reading any membership in that choir) rather than
  // withSecurityRulesDisabled, whose callback return value isn't the
  // resolved snapshot in this SDK version.
  async function waitForMembership(choirId, uid, readerUid, predicate, attempts = 120) {
    const readerDb = testEnv.authenticatedContext(readerUid).firestore();
    for (let i = 0; i < attempts; i++) {
      const snap = await readerDb.collection("choir_memberships").doc(`${choirId}_${uid}`).get();
      if (snap.exists && predicate(snap.data())) return snap.data();
      await new Promise((resolve) => setTimeout(resolve, 500));
    }
    throw new Error(`Timed out waiting for choir_memberships/${choirId}_${uid} to match predicate`);
  }

  it("a Leader assigning an existing chorister as a session's director actually grants them director capability", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choirs").doc("triggerChoirA").set({
        choirId: "triggerChoirA", name: "Trigger Choir", churchName: "Test",
        leaderId: "triggerLeaderA", inviteCode: "TRGA01", plan: "free", songCount: 0, createdAt: new Date(),
      });
      await db.collection("choir_memberships").doc("triggerChoirA_triggerLeaderA").set({
        choirId: "triggerChoirA", userId: "triggerLeaderA", role: "leader",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("triggerChoirA_assignee1").set({
        choirId: "triggerChoirA", userId: "assignee1", role: "chorister",
        defaultVoicePart: "T", permissions: [], joinedAt: new Date(),
      });
    });

    const leaderDb = testEnv.authenticatedContext("triggerLeaderA").firestore();
    await assertSucceeds(
      leaderDb.collection("rehearsal_sessions").doc("triggerSessionA").set({
        sessionId: "triggerSessionA", choirId: "triggerChoirA", date: new Date(),
        time: "10:00", location: "", directorId: "assignee1", isGuestDirector: false, notes: null,
      })
    );

    const granted = await waitForMembership("triggerChoirA", "assignee1", "triggerLeaderA",
      (data) => data.role === "director" && data.directorSessionId === "triggerSessionA");
    check("assignee1 was granted role: director scoped to triggerSessionA", true, granted);

    // The grant should now actually work through the rules, not just exist
    // as data — confirms the trigger's grant is functionally equivalent to
    // the guest-link path.
    const assigneeDb = testEnv.authenticatedContext("assignee1").firestore();
    await assertSucceeds(
      assigneeDb.collection("attendance").doc("triggerSessionA_someMember").set({
        sessionId: "triggerSessionA", userId: "someMember", choirId: "triggerChoirA", attended: true,
      })
    );
  });

  it("reassigning a session's director before it starts revokes the PREVIOUS assignee's access to that session", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection("choirs").doc("triggerChoirB").set({
        choirId: "triggerChoirB", name: "Trigger Choir B", churchName: "Test",
        leaderId: "triggerLeaderB", inviteCode: "TRGB01", plan: "free", songCount: 0, createdAt: new Date(),
      });
      await db.collection("choir_memberships").doc("triggerChoirB_triggerLeaderB").set({
        choirId: "triggerChoirB", userId: "triggerLeaderB", role: "leader",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("triggerChoirB_first1").set({
        choirId: "triggerChoirB", userId: "first1", role: "chorister",
        defaultVoicePart: "T", permissions: [], joinedAt: new Date(),
      });
      await db.collection("choir_memberships").doc("triggerChoirB_second1").set({
        choirId: "triggerChoirB", userId: "second1", role: "chorister",
        defaultVoicePart: "B", permissions: [], joinedAt: new Date(),
      });
    });

    const leaderDb = testEnv.authenticatedContext("triggerLeaderB").firestore();
    await assertSucceeds(
      leaderDb.collection("rehearsal_sessions").doc("triggerSessionB").set({
        sessionId: "triggerSessionB", choirId: "triggerChoirB", date: new Date(),
        time: "10:00", location: "", directorId: "first1", isGuestDirector: false, notes: null,
      })
    );
    await waitForMembership("triggerChoirB", "first1", "triggerLeaderB", (data) => data.role === "director");

    await assertSucceeds(
      leaderDb.collection("rehearsal_sessions").doc("triggerSessionB").update({ directorId: "second1" })
    );
    await waitForMembership("triggerChoirB", "second1", "triggerLeaderB", (data) => data.role === "director");
    const reverted = await waitForMembership("triggerChoirB", "first1", "triggerLeaderB", (data) => data.role === "chorister");
    check("first1 was reverted back to chorister after being replaced", true, reverted);

    const firstDb = testEnv.authenticatedContext("first1").firestore();
    await assertFails(
      firstDb.collection("attendance").doc("triggerSessionB_someMember").set({
        sessionId: "triggerSessionB", userId: "someMember", choirId: "triggerChoirB", attended: true,
      })
    );
  });

  function check(label, cond, extra) {
    if (!cond) {
      throw new Error(`FAILED: ${label} -- ${JSON.stringify(extra)}`);
    }
    console.log(`  ✔ ${label}`);
  }
});

// Leader/Director audit (Finding #5): score_attachments had no Firestore
// rule at all — confirmed live that even the Leader was denied.
describe("score_attachments (Leader/Director audit Finding #5)", () => {
  it("even the LEADER can now create a score_attachments doc", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choirs").doc("scoreChoirA").set({
        choirId: "scoreChoirA", name: "Score Choir", churchName: "Test",
        leaderId: "scoreLeaderA", inviteCode: "SCA123", plan: "free", songCount: 0, createdAt: new Date(),
      });
      await ctx.firestore().collection("choir_memberships").doc("scoreChoirA_scoreLeaderA").set({
        choirId: "scoreChoirA", userId: "scoreLeaderA", role: "leader",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
    });
    const db = testEnv.authenticatedContext("scoreLeaderA").firestore();
    await assertSucceeds(
      db.collection("score_attachments").doc("scoreX").set({
        scoreId: "scoreX", songId: "songX", choirId: "scoreChoirA",
        type: "pdf", fileUrl: "https://example.com/x.pdf", label: "Full Score",
        uploadedBy: "scoreLeaderA", createdAt: new Date(),
      })
    );
  });

  it("a chorister with 'score_librarian' CAN create a score_attachments doc; a plain chorister CANNOT", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc("scoreChoirB_librarian2").set({
        choirId: "scoreChoirB", userId: "librarian2", role: "chorister",
        defaultVoicePart: "S", permissions: ["score_librarian"], joinedAt: new Date(),
      });
      await ctx.firestore().collection("choir_memberships").doc("scoreChoirB_plain2").set({
        choirId: "scoreChoirB", userId: "plain2", role: "chorister",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
    });
    const librarianDb = testEnv.authenticatedContext("librarian2").firestore();
    await assertSucceeds(
      librarianDb.collection("score_attachments").doc("scoreY").set({
        scoreId: "scoreY", songId: "songY", choirId: "scoreChoirB",
        type: "pdf", fileUrl: "https://example.com/y.pdf", label: "Alto Part",
        uploadedBy: "librarian2", createdAt: new Date(),
      })
    );
    const plainDb = testEnv.authenticatedContext("plain2").firestore();
    await assertFails(
      plainDb.collection("score_attachments").doc("scoreZ").set({
        scoreId: "scoreZ", songId: "songZ", choirId: "scoreChoirB",
        type: "pdf", fileUrl: "https://example.com/z.pdf", label: "Bass Part",
        uploadedBy: "plain2", createdAt: new Date(),
      })
    );
  });
});

// Leader/Director audit (Findings #6, #7): the 'announcements' permission
// had no server-side effect anywhere, and pinning someone else's message
// unconditionally failed.
describe("chat_messages announcements permission (Leader/Director audit Findings #6, #7)", () => {
  async function seedChatMember(choirId, uid, role, permissions = []) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc(`${choirId}_${uid}`).set({
        choirId, userId: uid, role, defaultVoicePart: "S", permissions, joinedAt: new Date(),
      });
    });
  }

  it("a chorister with 'announcements' CAN now set targetVoicePart (Finding #6)", async () => {
    await seedChatMember("chatChoirA", "announcer1", "chorister", ["announcements"]);
    const db = testEnv.authenticatedContext("announcer1").firestore();
    await assertSucceeds(
      db.collection("chat_messages").doc("chatMsgA").set({
        choirId: "chatChoirA", senderId: "announcer1", type: "text",
        content: "Targeted", targetVoicePart: "S", pinned: false, timestamp: new Date(),
      })
    );
  });

  it("a plain chorister still CANNOT set targetVoicePart", async () => {
    await seedChatMember("chatChoirA", "plainMember1", "chorister");
    const db = testEnv.authenticatedContext("plainMember1").firestore();
    await assertFails(
      db.collection("chat_messages").doc("chatMsgB").set({
        choirId: "chatChoirA", senderId: "plainMember1", type: "text",
        content: "Targeted", targetVoicePart: "S", pinned: false, timestamp: new Date(),
      })
    );
  });

  it("a Leader CAN pin a DIFFERENT member's message (Finding #7), but cannot piggyback other field changes onto that same update", async () => {
    await seedChatMember("chatChoirB", "leaderX", "leader");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc("chatChoirB_otherSender").set({
        choirId: "chatChoirB", userId: "otherSender", role: "chorister",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await ctx.firestore().collection("chat_messages").doc("chatMsgC").set({
        choirId: "chatChoirB", senderId: "otherSender", type: "text",
        content: "Hello choir", pinned: false, timestamp: new Date(),
      });
    });
    const db = testEnv.authenticatedContext("leaderX").firestore();
    await assertSucceeds(
      db.collection("chat_messages").doc("chatMsgC").update({ pinned: true })
    );
    await assertFails(
      db.collection("chat_messages").doc("chatMsgC").update({ pinned: false, content: "tampered" })
    );
  });

  it("a plain chorister still CANNOT pin someone else's message", async () => {
    await seedChatMember("chatChoirB", "plainMember2", "chorister");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("choir_memberships").doc("chatChoirB_otherSender2").set({
        choirId: "chatChoirB", userId: "otherSender2", role: "chorister",
        defaultVoicePart: "S", permissions: [], joinedAt: new Date(),
      });
      await ctx.firestore().collection("chat_messages").doc("chatMsgD").set({
        choirId: "chatChoirB", senderId: "otherSender2", type: "text",
        content: "Hello choir", pinned: false, timestamp: new Date(),
      });
    });
    const db = testEnv.authenticatedContext("plainMember2").firestore();
    await assertFails(
      db.collection("chat_messages").doc("chatMsgD").update({ pinned: true })
    );
  });
});
