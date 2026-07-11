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

  it("an existing leader CAN promote a chorister to director via UPDATE (legitimate promotion flow preserved)", async () => {
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
    await assertSucceeds(
      db.collection("choir_memberships").doc("choirA_frank").update({
        role: "director",
      })
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

  it("Phase 2b Fix 3: a chorister with 'score_librarian' permission CANNOT write to /scores (delegation removed)", async () => {
    await seedMembership("choirD", "librarian1", "chorister", ["score_librarian"]);
    const chorister = testEnv.authenticatedContext("librarian1");
    const storage = chorister.storage();
    await assertFails(
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
