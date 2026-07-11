# KwayaPro — Codebase Audit Report

**Date:** 2026-06-16
**Project:** KwayaPro (Flutter + Firebase, choir management)
**Auditor:** AI-assisted code review
**Commit:** Working tree (post bugfix)

---


## 1. Project Structure

```
KwayaProApp/
├── .agents/                          # opencode AI agent skills
│   └── skills/
│       ├── developing-genkit-dart/
│       ├── developing-genkit-go/
│       ├── developing-genkit-js/
│       ├── developing-genkit-python/
│       ├── firebase-ai-logic-basics/
│       ├── firebase-app-hosting-basics/
│       ├── firebase-auth-basics/
│       ├── firebase-basics/
│       ├── firebase-crashlytics/
│       ├── firebase-data-connect/
│       ├── firebase-firestore/
│       ├── firebase-hosting-basics/
│       ├── firebase-remote-config-basics/
│       ├── firebase-security-rules-auditor/
│       └── xcode-project-setup/
│
├── functions/                        # Firebase Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts                  # Exports: presigned URL, MoMo payments, schedules, triggers
│   │   └── audio/
│   │       └── presignedUrlEndpoint.ts  # CloudFlare R2 presigned-upload endpoint
│   ├── package.json                  # node 24, firebase-functions v7, firebase-admin v13
│   └── tsconfig.json
│
├── kwayapro/                         # Flutter app root
│   ├── android/
│   ├── ios/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── firebase/
│   │   │   │   └── firebase_options.dart   # Duplicate; see Section 5
│   │   │   ├── router/
│   │   │   │   ├── app_router.dart          # GoRouter + StatefulShellRoute (4 tabs)
│   │   │   │   └── navigation_shell_screen.dart
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart           # M3 light/dark theme, Nunito fonts
│   │   │   │   └── color_tokens.dart        # Color constants
│   │   │   ├── utils/
│   │   │   │   ├── app_logger.dart
│   │   │   │   ├── currency_formatter.dart
│   │   │   │   ├── date_formatter.dart
│   │   │   │   ├── invite_code_generator.dart
│   │   │   │   ├── phone_normaliser.dart     # UG phone to +256 format
│   │   │   │   └── state_logger.dart
│   │   │   └── fcm_handler.dart              # Firebase Cloud Messaging
│   │   │
│   │   ├── shared/
│   │   │   ├── models/
│   │   │   │   └── enums.dart                # ChoirPlan, MemberRole, VoicePart
│   │   │   ├── providers/
│   │   │   │   ├── connectivity_provider.dart
│   │   │   │   └── shared_prefs_provider.dart
│   │   │   ├── data/
│   │   │   │   ├── base_repository.dart
│   │   │   │   └── audio_cache_service.dart
│   │   │   ├── utils/
│   │   │   │   └── permission_checker.dart
│   │   │   └── widgets/
│   │   │       ├── empty_state.dart
│   │   │       ├── error_view.dart
│   │   │       ├── m3_chip.dart
│   │   │       ├── m3_fab.dart
│   │   │       └── offline_banner.dart
│   │   │
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/
│   │   │   │   │   ├── auth_repository.dart   # Phone OTP + email/password
│   │   │   │   │   └── user_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── auth_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       └── app_user.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── onboarding_screen.dart  # 6-step wizard (899 lines)
│   │   │   │       └── profile_screen.dart
│   │   │   │
│   │   │   ├── choir/
│   │   │   │   ├── data/
│   │   │   │   │   └── choir_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── choir_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       ├── choir.dart
│   │   │   │   │       └── choir_membership.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── home_screen.dart        # Choir dashboard (446 lines)
│   │   │   │       ├── members_screen.dart
│   │   │   │       └── member_detail_screen.dart
│   │   │   │
│   │   │   ├── songs/
│   │   │   │   ├── data/
│   │   │   │   │   ├── song_repository.dart
│   │   │   │   │   └── score_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── song_providers.dart     # Freemium 3-song limit
│   │   │   │   │   ├── score_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       ├── song.dart
│   │   │   │   │       ├── song_section.dart
│   │   │   │   │       ├── audio_part.dart
│   │   │   │   │       └── score_attachment.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── library_screen.dart
│   │   │   │       └── song_list_item.dart
│   │   │   │
│   │   │   ├── audio/
│   │   │   │   ├── data/
│   │   │   │   │   └── audio_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   └── audio_player_notifier.dart
│   │   │   │   └── presentation/
│   │   │   │       └── mini_player_bar.dart
│   │   │   │
│   │   │   ├── studio/
│   │   │   │   ├── domain/
│   │   │   │   │   └── low_latency_piano_engine.dart
│   │   │   │   └── presentation/
│   │   │   │       └── studio_screen.dart      # about 840 lines
│   │   │   │
│   │   │   ├── rehearsal/
│   │   │   │   ├── data/
│   │   │   │   │   └── rehearsal_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── rehearsal_providers.dart # 4 stub providers
│   │   │   │   │   └── models/
│   │   │   │   │       └── rehearsal_session.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── rehearsals_screen.dart
│   │   │   │       └── guest_director_screen.dart
│   │   │   │
│   │   │   ├── attendance/
│   │   │   │   ├── data/
│   │   │   │   │   └── attendance_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── attendance_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       └── attendance.dart
│   │   │   │   └── presentation/
│   │   │   │       └── attendance_screen.dart
│   │   │   │
│   │   │   ├── chat/
│   │   │   │   ├── data/
│   │   │   │   │   └── chat_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── chat_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       └── chat_message.dart
│   │   │   │   └── presentation/
│   │   │   │       └── chat_screen.dart
│   │   │   │
│   │   │   ├── planner/
│   │   │   │   ├── data/
│   │   │   │   │   └── planner_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── planner_providers.dart
│   │   │   │   │   └── models/
│   │   │   │   │       └── song_program.dart
│   │   │   │   └── presentation/
│   │   │   │       └── planner_screen.dart
│   │   │   │
│   │   │   └── subscription/
│   │   │       ├── data/
│   │   │       │   └── subscription_repository.dart
│   │   │       ├── domain/
│   │   │       │   ├── subscription_providers.dart
│   │   │       │   └── models/
│   │   │       │       └── subscription.dart
│   │   │       └── presentation/
│   │   │           └── billing_screen.dart     # Stepper-based MTN MoMo billing
│   │   │
│   │   ├── firebase_options.dart               # Root-level duplicate (CLI-generated)
│   │   └── main.dart                           # App entry point
│   │
│   ├── test/
│   │   ├── core/
│   │   │   └── utils/
│   │   │       └── phone_normaliser_test.dart   # 5 tests
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   └── presentation/
│   │   │   │       └── onboarding_screen_test.dart  # 1 widget test
│   │   │   └── models_test.dart                    # 3 group tests
│   │   └── widget_test.dart                        # 1 smoke test
│   │
│   ├── pubspec.yaml
│   ├── firebase.json
│   ├── firestore.rules
│   └── firestore.indexes.json
│
├── firestore.rules                    # Root-level duplicate (stricter version)
├── firestore.indexes.json             # Root-level duplicate (more indexes)
├── storage.rules                      # Storage security rules
├── .firebaserc
└── firebase.json                      # Root-level Firebase config
```

## 2. pubspec.yaml Summary

| Field | Value |
|-------|-------|
| SDK | >=3.4.0 <4.0.0 |
| State management | flutter_riverpod: ^2.6.1, riverpod_annotation: ^2.6.1 |
| Routing | go_router: ^14.8.0, animations: ^2.0.11 |
| Firebase | firebase_core: ^3.12.0, firebase_auth: ^5.5.0, cloud_firestore: ^5.6.0 |
| Media | image_picker: ^1.1.2, just_audio: ^0.9.43, record: ^5.2.0 |
| Notifications | firebase_messaging: ^15.2.0, flutter_local_notifications: ^18.0.1 |
| Storage | firebase_storage: ^12.4.0, cloudflare_r2: ^1.0.2 |
| Pay | mtn_momo: ^2.0.0 |
| Architecture | Clean-ish: data/, domain/, presentation/ per feature |

**Missing:** flutter_lints, freezed, json_serializable, equatable -- no code-gen.

---

## 3. Per-file Summary

### Core Layer

| File | Summary |
|------|---------|
| main.dart | Entry point. Initializes Firebase (local fallback). darkTheme as ThemeMode.dark. FCM, GoRouter via Riverpod. |
| app_router.dart | GoRouter with StatefulShellRoute (4 tabs: Home, Library, Rehearsals, Chat). Auth guard redirect. Deep-link routes for /join, /rehearsal-invite, /studio, /billing, /attendance, /planner, /profile, /guest-director. |
| navigation_shell_screen.dart | Scaffold + BottomNavigationBar (4 items) + StatefulNavigationShell. |
| app_theme.dart | M3 light + dark themes. Nunito text theme. Consistent shapes: Cards=24dp, FAB=16dp, Chips=8dp, Buttons=50dp, Dialog=28dp. |
| color_tokens.dart | Hardcoded color constants for light + dark palettes. |
| fcm_handler.dart | Permission request, FCM token, onMessage/onMessageOpenedApp/onBackgroundMessage. Notification routing by payload type. |
| firebase_options.dart | CLI-generated. iOS appId is ios:placeholder -- NOT deployable to iOS. |

### Shared Layer

| File | Summary |
|------|---------|
| enums.dart | ChoirPlan, MemberRole, VoicePart + displayName. |
| connectivity_provider.dart | Riverpod StreamProvider wrapping connectivity_plus. |
| shared_prefs_provider.dart | SharedPreferences wrapper. |
| base_repository.dart | FirebaseFirestore.instance + docStream, docFuture, collectionStream, batchWrite, runTransaction. |
| audio_cache_service.dart | Download audio to temp, return local path. |
| permission_checker.dart | isLeader/isDirector/isMember from currentMembershipProvider. |
| empty_state.dart | Generic empty state widget. |
| error_view.dart | Error display with retry callback. |
| m3_chip.dart | M3-styled chip. |
| m3_fab.dart | M3-styled FAB. |
| offline_banner.dart | Connectivity-based offline indicator. |

### Auth Feature

| File | Summary |
|------|---------|
| auth_repository.dart | Phone OTP (verifyPhone, verifyOTP) + email/password. signOut, deleteAccount. |
| user_repository.dart | CRUD for users/{userId} in Firestore. Creates user doc on signup. |
| auth_providers.dart | StreamProvider from FirebaseAuth.instance.authStateChanges(). authRepositoryProvider, userRepositoryProvider. |
| app_user.dart | AppUser model with fromJson/toJson. Null-safe: userId, name, phone, profilePhotoUrl, fcmToken, createdAt. |
| onboarding_screen.dart | 899 lines. 6-step wizard: Splash, Phone/Email, OTP, Profile, Join/Create Choir, Voice Part. AnimatedSwitcher transitions. |
| profile_screen.dart | View/edit profile name + photo. Logout + delete account. |

### Choir Feature

| File | Summary |
|------|---------|
| choir_repository.dart | createChoir, joinChoir, getChoir, getMemberships, getUserChoirs, findByInviteCode, updateChoir, deleteChoir. 6-char invite code generation. |
| choir_providers.dart | activeChoirProvider, activeChoirIdProvider, userChoirsProvider, currentMembershipProvider, choirMembersProvider. |
| choir.dart | Choir model: choirId, name, churchName, leaderId, inviteCode, plan (ChoirPlan), songCount, createdAt. |
| choir_membership.dart | ChoirMembership model: membershipId, choirId, userId, role, defaultVoicePart, joinedAt. |
| home_screen.dart | 446 lines. Dashboard: hero card, voice part distribution, management chips, next rehearsal, choir switcher bottom sheet, empty state. Auto-selects first choir. |
| members_screen.dart | Member list with search + role/voice part filters. |
| member_detail_screen.dart | Single member view. Role management (leader/director only). |

### Songs Feature

| File | Summary |
|------|---------|
| song_repository.dart | CRUD songs + sections + audio parts (Firestore subcollections). |
| score_repository.dart | CRUD score attachments (PDF/image) in Firestore + Storage. |
| song.dart | Song model: songId, choirId, title, key, language, category, uploadedBy, createdAt. |
| song_section.dart | SongSection: sectionId, title, order, lyrics. |
| audio_part.dart | AudioPart: partId, voicePart, audioUrl, uploadedAt, uploadedBy. |
| score_attachment.dart | ScoreAttachment: attachmentId, fileUrl, fileType, uploadedAt, uploadedBy. |
| song_providers.dart | songsByChoirProvider, currentSongProvider, isAtSongLimitProvider (freemium 3-song cap). |
| score_providers.dart | scoresBySongProvider family. |
| library_screen.dart | Song library grid/list. Key/language badges. FAB with tier limit check. Pull-to-refresh. |
| song_list_item.dart | Song row widget. |

### Audio Feature

| File | Summary |
|------|---------|
| audio_repository.dart | Upload/download via Firebase Storage + optional R2. |
| audio_player_notifier.dart | StateNotifier wrapping just_audio AudioPlayer. Play, pause, seek, stop, position stream. |
| mini_player_bar.dart | Persistent mini player bar. Play/pause/close. |

### Studio Feature

| File | Summary |
|------|---------|
| low_latency_piano_engine.dart | Piano synthesis engine using AudioPlayer + samples. Note on/off, sustain. |
| studio_screen.dart | about 840 lines. Full recording studio: scrollable 2-octave piano, metronome (BPM + tap tempo), record button, waveform, playback. StudioContext. |

### Rehearsal Feature

| File | Summary |
|------|---------|
| rehearsal_repository.dart | CRUD rehearsal sessions. validateGuestToken, getSessionByToken. |
| rehearsal_providers.dart | 4 STUB providers: upcomingRehearsalsProvider, pastRehearsalsProvider, myRSVPProvider, rsvpCountsProvider -- all return Stream.value([]) or null. |
| rehearsal_session.dart | RehearsalSession: sessionId, choirId, date, time, location, guestDirectorToken. |
| rehearsals_screen.dart | Upcoming/past tabs. RSVP toggle. |
| guest_director_screen.dart | Guest director view with limited controls. |

### Attendance Feature

| File | Summary |
|------|---------|
| attendance_repository.dart | CRUD attendance records per session. getAttendanceRate. |
| attendance_providers.dart | attendanceForSessionProvider, myAttendanceHistoryProvider, lastSessionAttendanceRateProvider. |
| attendance.dart | AttendanceRecord: recordId, sessionId, memberId, attended, voicePart. |
| attendance_screen.dart | Toggle attendance per member (present/late/absent). |

### Chat Feature

| File | Summary |
|------|---------|
| chat_repository.dart | sendMessage, streamMessages. |
| chat_providers.dart | messagesForChoirProvider (Firestore stream). |
| chat_message.dart | ChatMessage: messageId, senderId, senderName, text, timestamp. |
| chat_screen.dart | Real-time UI. Message bubbles, input field, auto-scroll. |

### Planner Feature

| File | Summary |
|------|---------|
| planner_repository.dart | CRUD song programs. publishProgram triggers Cloud Function. |
| song_program.dart | SongProgram: programId, choirId, title, date, songIds, published, createdAt. |
| planner_providers.dart | songProgramsProvider, cachedAvailableSongsProvider. |
| planner_screen.dart | Calendar view + program list. Create/edit/publish/drag-reorder. |

### Subscription / Billing Feature

| File | Summary |
|------|---------|
| subscription_repository.dart | CRUD subscriptions. initiatePayment calls Cloud Function. |
| subscription.dart | Subscription: subscriptionId, choirId, plan, active, expiresAt, paymentReference. |
| subscription_providers.dart | currentSubscriptionProvider, paymentHistoryProvider. |
| billing_screen.dart | Stepper-based MTN MoMo billing. Free vs Pro comparison. |

### Firebase Functions

| File | Summary |
|------|---------|
| functions/src/index.ts | Exports: getPresignedUrl, getR2PresignedUploadChannel, initiatePayment (MTN MoMo), mtnWebhook, paymentWebhook, onRehearsalCreated, rehearsalReminder, checkGuestTokenExpiry, onProgramPublished, confirmAudioUpload. Airtel MoMo secrets commented out. |
| functions/src/audio/presignedUrlEndpoint.ts | Cloudflare R2 presigned URL generation. Accepts contentType, songId, sectionId, voicePart; returns uploadUrl + publicUrl. |

---

## 4. Router Analysis

**File:** kwayapro/lib/core/router/app_router.dart

**Structure:**
- GoRouter with initialLocation: /onboarding
- Redirect guard checks authState + userChoirs
- 4-tab StatefulShellRoute.indexedStack (Home, Library, Rehearsals, Chat)
- 8 top-level routes: /onboarding, /studio, /billing, /attendance/:sessionId, /planner (sub-routes), /members (sub-route), /guest-director/:sessionId, /profile
- 2 deep-links: /join/:inviteCode, /rehearsal-invite/:token

**Redirect Logic:**
- if (goingToJoin || goingToRehearsalInvite) -> null
- if (!isAuth && !isOnboarding) -> /onboarding
- if (isAuth && isOnboarding):
  - if (choirs == null) -> null (loading)
  - if (choirs.isNotEmpty) -> /home  (BUG: mid-flow redirect, see Section 8)
  - -> null (no choirs, stay)
- -> null

**Flags:**
- CustomTransitionPage + SharedAxisTransition for shell routes
- debugLogDiagnostics: true left on (should be off in release)
- No route-level role/permission guards (in-screen checks only)

---

## 5. Firebase Configuration

| Artifact | Location | Notes |
|----------|----------|-------|
| firebase.json | Root | References storage.rules, firestore.rules/indexes, functions/ |
| firebase.json | kwayapro/ | CLI-generated Flutter config |
| firestore.rules | Root | v2 with hasAnyRole() custom function (stricter) |
| firestore.rules | kwayapro/ | v2 with isLeader() helper (less strict) |
| firestore.indexes.json | Root | chat, rehearsal, attendance, song_sections, audio_parts |
| firestore.indexes.json | kwayapro/ | Subset: chat, rehearsal, attendance only |
| firebase_options.dart | lib/core/firebase/ | CLI-generated. iOS appId = ios:placeholder |
| firebase_options.dart | lib/ | Duplicate (same content) |

**Issues:**
1. Duplicate firebase_options.dart
2. Duplicate firestore.rules -- different rule versions (hasAnyRole vs isLeader)
3. Duplicate firestore.indexes.json -- root has more indexes, kwayapro/ is subset
4. iOS placeholder app ID -- will crash on iOS Firebase init
5. No App Check configured
6. Storage rules at root only (no copy in kwayapro/)

---

## 6. Feature Completeness Checklist

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Phone OTP Auth | Implemented | Phone + email fallback |
| 2 | Email/Password Auth | Implemented | Sign-in + create account |
| 3 | Profile Setup | Implemented | Onboarding step 3 + edit screen |
| 4 | Create Choir | Implemented | Onboarding step 4 + repository |
| 5 | Join Choir (invite code) | Implemented | Onboarding + deep link /join/:code |
| 6 | Choir Dashboard | Implemented | Metrics, distribution, actions, switcher |
| 7 | Member Management | Implemented | List, search, filter, detail, role mgmt |
| 8 | Song Library | Implemented | Grid/list, search, tier-limited add |
| 9 | Song Sections | Implemented | Subcollection per song |
| 10 | Audio Parts per Section | Implemented | Voice-part recordings via R2 |
| 11 | Score Attachments | Implemented | PDF/image upload per song |
| 12 | Recording Studio | Implemented | Piano, metronome, recorder, waveform |
| 13 | Audio Playback (mini player) | Implemented | Persistent bar, play/pause/seek |
| 14 | Rehearsal Scheduling | Partial | 4 providers are stubs returning empty streams |
| 15 | RSVP for Rehearsals | Partial | UI exists, upstream provider is stub |
| 16 | Guest Director Invites | Partial | Deep link + token validation, stubs block flow |
| 17 | Attendance Tracking | Implemented | Toggle per session, rate calculation |
| 18 | Chat (real-time) | Implemented | Firestore stream, bubbles, auto-scroll |
| 19 | Song Program Planner | Implemented | Calendar + editor, reorder, publish |
| 20 | Freemium Tier Limits | Implemented | 3-song cap for free tier |
| 21 | Subscription / Billing | Implemented | MTN MoMo Stepper UI |
| 22 | Push Notifications | Implemented | FCM + local notifications |
| 23 | Offline Banner | Implemented | Connectivity stream + indicator |
| 24 | Firebase Cloud Functions | Implemented | R2, MoMo, scheduling, triggers |

**Total: 20/24 implemented, 3 partial (rehearsal), 0 missing.**

---

## 7. Prototype-Only Controls

Searches for setUserRole, Switch Role, showEmptyStates, setShowEmptyStates, and isAuthenticated = true returned **zero matches** across the codebase. No debug toggles or developer controls were found.

---

## 8. Known Bug Status

| # | Bug | Status | Analysis |
|---|-----|--------|----------|
| 1 | Black background on choir creation screen | Partially Addressed | Scaffold line 431 sets backgroundColor: colorScheme.surface. Dark theme surface = #121212 (near-black). This is intentional M3 dark theme, but perceived as "black." Worth noting if the report asks for a different treatment. |
| 2 | AnimatedSwitcher static key collision (ValueKey join_create) | Fixed | Current code uses dynamic ValueKey join_create_$stepKey (line 727) where stepKey = choice/create/join. Keys are unique per sub-view. |
| 3 | TextEditingController declared inside build() | Not Present | All controllers are instance fields of _OnboardingScreenState (lines 34-57), properly disposed in dispose() (lines 65-78). No controllers created inside build(). |
| 4 | GoRouter mid-flow redirect bypasses onboarding step 0 | CONFIRMED | After choir creation in step 4, userChoirsProvider resolves with the new choir. Redirect guard (lines 65-73) checks choirs.isNotEmpty -> true -> redirects to /home. User is kicked out before completing step 5 (voice part selection). Fix: redirect should only fire for steps 0-2, or check an _onboardingComplete flag. |

---

## 9. Test Coverage

### Test Files

| File | Count | Type |
|------|-------|------|
| test/widget_test.dart | 1 | Smoke: onboarding splash |
| test/features/models_test.dart | 3 groups | Unit: AppUser, Choir, Song serialization |
| test/features/auth/presentation/onboarding_screen_test.dart | 1 | Widget: phone submission to OTP |
| test/core/utils/phone_normaliser_test.dart | 5 | Unit: phone number formatting |

### Gaps

- No tests for: choir/song/audio/rehearsal/chat/attendance/planner/subscription repositories, providers, router, studio, FCM handler
- No integration tests with Firebase emulator
- No widget tests for home, library, chat, rehearsals, billing, or any screen beyond onboarding
- No golden file tests
- models_test.dart is in test/features/ directly instead of test/features/models/
- No GoRouter redirect logic test
- Coverage estimate: <5%

---

## 10. Open TODOs / Technical Debt

### Findings

| Location | Line | Type | Description |
|----------|------|------|-------------|
| main.dart | 43 | Placeholder | "Failed to initialize Firebase. Using local placeholder modes." -- silent fallback, no visual indicator |
| lib/core/firebase/firebase_options.dart | 34 | Placeholder | iOS appId = ios:placeholder -- will crash on iOS Firebase init |
| lib/firebase_options.dart | 34 | Placeholder | Same as above (duplicate file) |
| -- | -- | -- | Zero TODO/FIXME/HACK comments found in lib/ or functions/ |

### Structural Debt

1. **Duplicate firebase_options.dart**: Two identical copies. Delete root-level lib/firebase_options.dart, update import in main.dart.

2. **Duplicate firestore.rules**: Root uses hasAnyRole(), kwayapro/ uses isLeader(). Consolidate to single source of truth.

3. **Duplicate firestore.indexes.json**: Root has more indexes (song_sections, audio_parts). kwayapro/ version is subset. Firebase CLI reads kwayapro/ version -- missing indexes will cause query failures in production.

4. **Rehearsal providers are stubs**: rehearsal_providers.dart lines 13-26 return Stream.value([]) / Stream.value(null). activeChoirIdProvider import is commented out. Blocks all rehearsal/RSVP functionality.

5. **debugLogDiagnostics: true in production**: app_router.dart line 51 -- should be toggled off in release builds.

6. **No code generation**: Models manually write fromJson/toJson. Consider freezed + json_serializable for compile-time safety.

7. **Mixed alpha APIs**: home_screen.dart:349 uses withValues(alpha: 0.2) (Flutter 3.27+), while other files may use withOpacity(). Standardize.

8. **Airtel MoMo secrets commented out**: functions/src/index.ts lines 20-22. Airtel payment method is disabled.

9. **Firebase local placeholder mode**: main.dart silently falls back without user-visible indicator when Firebase fails to initialize.

10. **iOS not deployable**: Placeholder appId means iOS build is blocked pending Firebase project setup with real iOS app ID.

11. **Test file location mismatch**: models_test.dart lives at test/features/ instead of test/features/models/.

12. **No Flutter lints**: flutter_lints or similar not in pubspec.yaml.

---
