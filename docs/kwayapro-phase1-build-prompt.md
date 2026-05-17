# KwayaPro — Phase 1 Build Prompt
**For:** Claude Code / Agentic Code Executor  
**Stack:** Flutter (Dart) · Firebase · Cloudflare R2  
**Target:** Android APK — Material Design 3 — Uganda MVP  
**Sprint:** 6 weeks · Android-first · Solo developer

---

## 0. BEFORE YOU WRITE ANY CODE

Read these three files in full before touching the project. Every decision below derives from them:

1. `KwayaProApp.jsx` — The complete UI wireframe prototype. This is the ground truth for every screen's layout, component hierarchy, copy, color tokens, and interaction pattern. Do not deviate from it.
2. `KwayaPro_PRD_v1.0.docx` — The complete product spec. Feature scope, data model, permission system, security rules, and acceptance criteria all live here.
3. `kwayapro-architecture-flutter.jsx` — The system architecture. Package list, folder structure, data flow, and key user flows.

**When in conflict:** PRD beats architecture diagram beats wireframe for _what_ to build. Wireframe beats everything for _how it looks_.

---

## 1. PROJECT BOOTSTRAP

### 1.1 Create Flutter project

```bash
flutter create kwayapro --org com.kwayapro --platforms android
cd kwayapro
```

### 1.2 Target SDK

Set `minSdkVersion 26` (Android 8.0) in `android/app/build.gradle`. Set `targetSdkVersion 34`.

### 1.3 pubspec.yaml — exact dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # Firebase (FlutterFire)
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.4
  cloud_firestore: ^4.15.5
  firebase_storage: ^11.6.5
  firebase_messaging: ^14.7.19

  # Audio
  just_audio: ^0.9.36
  audio_session: ^0.1.18
  record: ^5.0.4

  # File handling
  file_picker: ^8.0.0
  image_picker: ^1.0.7

  # Local storage
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.2
  path_provider: ^2.1.2

  # Networking
  http: ^1.2.1
  dio: ^5.4.3+1

  # System
  share_plus: ^7.2.2
  flutter_local_notifications: ^17.0.0
  permission_handler: ^11.3.0
  connectivity_plus: ^6.0.1

  # Utilities
  intl: ^0.19.0
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.3.9
  hive_generator: ^2.0.1
```

---

## 2. FOLDER STRUCTURE

Implement this structure exactly. Do not flatten or rename.

```
lib/
├── main.dart
├── app.dart                        # ProviderScope + GoRouter root
├── core/
│   ├── firebase/
│   │   └── firebase_options.dart   # FlutterFire CLI generated
│   ├── router/
│   │   ├── app_router.dart         # All routes defined here
│   │   └── route_guards.dart       # Auth guard, role-based guards
│   ├── theme/
│   │   ├── app_theme.dart          # M3 ThemeData from color tokens
│   │   └── color_tokens.dart       # Exact HCT palette from wireframe
│   └── utils/
│       ├── date_formatter.dart     # EAT timezone, Ugandan date formats
│       └── currency_formatter.dart # UGX formatting
├── features/
│   ├── auth/
│   │   ├── data/auth_repository.dart
│   │   ├── domain/auth_providers.dart
│   │   └── presentation/
│   │       ├── onboarding_screen.dart    # Maps to OnboardingFlow in wireframe
│   │       └── widgets/otp_input.dart
│   ├── choir/
│   │   ├── data/choir_repository.dart
│   │   ├── domain/
│   │   │   ├── choir_providers.dart
│   │   │   └── models/choir.dart
│   │   └── presentation/
│   │       ├── home_screen.dart          # Maps to HomeScreen
│   │       ├── members_screen.dart       # Maps to MembersScreen
│   │       ├── member_detail_screen.dart # Maps to MemberDetailScreen
│   │       └── widgets/
│   │           ├── choir_hero_card.dart
│   │           └── choir_switcher_sheet.dart
│   ├── songs/
│   │   ├── data/song_repository.dart
│   │   ├── domain/
│   │   │   ├── song_providers.dart
│   │   │   └── models/
│   │   │       ├── song.dart
│   │   │       ├── song_section.dart
│   │   │       └── audio_part.dart
│   │   └── presentation/
│   │       ├── library_screen.dart       # Maps to LibraryScreen
│   │       └── widgets/song_list_item.dart
│   ├── audio/
│   │   ├── data/audio_repository.dart    # R2 presigned URL uploads
│   │   ├── domain/audio_providers.dart
│   │   └── presentation/
│   │       └── widgets/
│   │           ├── audio_player_bar.dart
│   │           └── waveform_visualizer.dart
│   ├── rehearsal/
│   │   ├── data/rehearsal_repository.dart
│   │   ├── domain/
│   │   │   ├── rehearsal_providers.dart
│   │   │   └── models/rehearsal_session.dart
│   │   └── presentation/
│   │       ├── rehearsals_screen.dart    # Maps to RehearsalsScreen
│   │       └── guest_director_screen.dart # Maps to GuestDirectorScreen
│   ├── attendance/
│   │   ├── data/attendance_repository.dart
│   │   ├── domain/
│   │   │   ├── attendance_providers.dart
│   │   │   └── models/attendance.dart
│   │   └── presentation/
│   │       └── attendance_screen.dart    # Maps to AttendanceScreen
│   ├── studio/
│   │   ├── data/studio_repository.dart
│   │   ├── domain/studio_providers.dart
│   │   └── presentation/
│   │       └── studio_screen.dart        # Maps to StudioLandscapeScreen — LANDSCAPE LOCK
│   ├── chat/
│   │   ├── data/chat_repository.dart
│   │   ├── domain/
│   │   │   ├── chat_providers.dart
│   │   │   └── models/chat_message.dart
│   │   └── presentation/
│   │       └── chat_screen.dart          # Maps to ChatScreen
│   ├── planner/
│   │   ├── data/planner_repository.dart
│   │   ├── domain/
│   │   │   ├── planner_providers.dart
│   │   │   └── models/song_program.dart
│   │   └── presentation/
│   │       └── planner_screen.dart       # Maps to PlannerScreen
│   ├── dashboard/
│   │   └── presentation/
│   │       └── widgets/metrics_card.dart
│   └── subscription/
│       ├── data/subscription_repository.dart
│       ├── domain/
│       │   ├── subscription_providers.dart
│       │   └── models/subscription.dart
│       └── presentation/
│           └── billing_screen.dart       # Maps to BillingScreen
└── shared/
    ├── models/
    │   └── (re-exports of all domain models)
    ├── repositories/
    │   └── base_repository.dart
    ├── providers/
    │   ├── auth_state_provider.dart
    │   └── connectivity_provider.dart
    └── widgets/
        ├── m3_fab.dart
        ├── m3_chip.dart
        ├── m3_button.dart
        ├── m3_icon_button.dart
        ├── empty_state.dart
        ├── m3_snackbar.dart
        └── m3_dialog.dart
```

---

## 3. THEME & COLOR TOKENS

Translate the CSS custom properties from the wireframe into Flutter `ColorScheme` and `ThemeData`. The wireframe defines two themes (light and dark). Implement both.

### Light theme tokens (from wireframe `:root`)
```
primary:          #6B4F00    onPrimary:         #ffffff
primaryContainer: #FFD97D    onPrimaryContainer:#211500
secondary:        #5D5235    onSecondary:       #ffffff
secondaryContainer:#E8D9A0  onSecondaryContainer:#1C1800
tertiary:         #3C6040    onTertiary:        #ffffff
tertiaryContainer:#BCEDC0   onTertiaryContainer:#002107
error:            #BA1A1A    onError:           #ffffff
errorContainer:   #FFDAD6    onErrorContainer:  #410002
surface:          #FFF8EF    onSurface:         #1E1B13
surfaceVariant:   #F5EEE2    outline:           #524D42
outlineVariant:   #CCC5B3
```

### Dark theme tokens (from wireframe `.dark-theme`)
```
primary:          #E8C06A    onPrimary:         #381F00
primaryContainer: #503300    onPrimaryContainer:#FFD97D
secondary:        #CCB96E    onSecondary:       #312800
secondaryContainer:#493E00  onSecondaryContainer:#E8D9A0
tertiary:         #A0D1A4    onTertiary:        #063A0D
tertiaryContainer:#1E5224   onTertiaryContainer:#BCEDC0
error:            #FFB4AB    onError:           #690005
errorContainer:   #93000A    onErrorContainer:  #FFDAD6
surface:          #15120B    onSurface:         #EAE2D5
surfaceVariant:   #232017    outline:           #999181
outlineVariant:   #4D4636
```

Use `ColorScheme.fromSeed` only if you cannot achieve the exact colors. Prefer manual `ColorScheme` construction using the values above.

**Typography:** Use `Nunito` (Google Fonts). Font weights: Display/Headline = 800–900, Title = 800, Body = 600, Label = 800 uppercase. Import via `google_fonts` package — add it to pubspec.

**Shape:** Default `borderRadius` for cards = `BorderRadius.circular(24)`. FAB = `BorderRadius.circular(16)`. Chips = `BorderRadius.circular(8)`. Buttons = `BorderRadius.circular(50)` (pill).

---

## 4. ROUTING — go_router

Define all routes in `core/router/app_router.dart`. Use `GoRouter` with `redirect` for auth gating.

### Route map
```
/                     → redirect: authenticated? /home : /onboarding
/onboarding           → OnboardingScreen (unauthenticated only)
/home                 → HomeScreen (shell route with bottom nav)
/home/library         → LibraryScreen
/home/rehearsals      → RehearsalsScreen
/home/chat            → ChatScreen

# Immersive (no bottom nav)
/studio               → StudioScreen (landscape lock)
/billing              → BillingScreen
/attendance/:sessionId → AttendanceScreen
/planner              → PlannerScreen
/members              → MembersScreen
/members/:userId      → MemberDetailScreen
/guest-director/:sessionId → GuestDirectorScreen
/profile              → ProfileScreen

# Deep links
/join/:inviteCode     → auto-join choir flow
/rehearsal-invite/:token → guest director join flow
```

**Shell route:** Wrap `/home`, `/home/library`, `/home/rehearsals`, `/home/chat` in a `ShellRoute` that renders the M3 bottom navigation bar. All other routes are full-screen and hide the nav bar.

**Tab transition:** Implement `SharedAxisTransition` (horizontal X-axis) between sibling tabs. Going right in the nav = slide left; going left = slide right. Match the `slideInRight`/`slideInLeft` CSS animations in the wireframe.

---

## 5. STATE MANAGEMENT — Riverpod

Use `AsyncNotifierProvider` for async operations, `StreamProvider` for Firestore real-time streams, `StateProvider` for local UI state.

### Required providers (implement all)

```dart
// Auth
authStateProvider       // StreamProvider<User?> from firebase_auth
currentUserProvider     // FutureProvider<AppUser> — fetches Firestore user doc

// Choir
activeChoirProvider     // StateProvider<String> — active choirId
choirProvider           // StreamProvider<Choir> — Firestore stream by choirId
choirMembersProvider    // StreamProvider<List<ChoirMembership>>
currentMembershipProvider // Derived — current user's role + permissions in activeChoir

// Songs
songLibraryProvider     // StreamProvider<List<Song>> — filtered by choirId
audioPartsProvider      // StreamProvider<List<AudioPart>> — by songId

// Rehearsals
upcomingRehearsalsProvider // StreamProvider<List<RehearsalSession>>

// Attendance
sessionAttendanceProvider  // StreamProvider<List<Attendance>> by sessionId

// Chat
chatMessagesProvider    // StreamProvider<List<ChatMessage>> by choirId

// Subscription
choirSubscriptionProvider // StreamProvider<Subscription?> by choirId

// Connectivity
connectivityProvider    // StreamProvider<ConnectivityResult>
```

**Repository pattern:** Every provider gets its data from a repository class, not directly from Firestore. Repositories are injected as providers themselves.

**Offline-first:** Enable Firestore offline persistence on init:
```dart
FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
```

---

## 6. FIRESTORE DATA MODEL

Implement these 13 Dart model classes with `fromJson(Map<String, dynamic>)` and `toJson()` methods. Use Hive `@HiveType` annotations on models that need local caching (User, Choir, Song, AudioPart).

### Collection schemas

```dart
// users/{userId}
class AppUser {
  final String userId;
  final String name;
  final String phone;
  final String? email;
  final String? profilePhotoUrl;
  final String? fcmToken;
  final DateTime createdAt;
}

// choirs/{choirId}
class Choir {
  final String choirId;
  final String name;
  final String churchName;
  final String leaderId;
  final String? coverPhotoUrl;
  final ChoirPlan plan; // enum: free, pro
  final int songCount;
  final DateTime createdAt;
}

// choir_memberships/{choirId_userId}  ← composite document ID
class ChoirMembership {
  final String choirId;
  final String userId;
  final MemberRole role; // enum: leader, director, chorister
  final VoicePart defaultVoicePart; // enum: S, A, T, B
  final List<String> permissions; // ['song_program_planner', 'score_librarian', ...]
  final DateTime joinedAt;
}

// songs/{songId}
class Song {
  final String songId;
  final String choirId;
  final String title;
  final String? key;
  final String? language;
  final String? category;
  final String uploadedBy;
  final DateTime createdAt;
}

// song_sections/{sectionId}
class SongSection {
  final String sectionId;
  final String songId;
  final String title; // 'Verse', 'Chorus', 'Bridge', or custom
  final int order;
  final SectionStatus status; // enum: ready, coming_soon
}

// audio_parts/{audioPartId}
class AudioPart {
  final String audioPartId;
  final String sectionId;
  final VoicePart voicePart;
  final String audioUrl; // R2 URL
  final int durationSeconds;
  final String uploadedBy;
}

// score_attachments/{scoreId}
class ScoreAttachment {
  final String scoreId;
  final String songId;
  final ScoreType type; // enum: pdf, image
  final String fileUrl; // Firebase Storage URL
  final String? label;
  final String uploadedBy;
}

// song_programs/{programId}
class SongProgram {
  final String programId;
  final String choirId;
  final String eventName;
  final EventType eventType; // enum: mass, wedding, concert, rehearsal, other
  final DateTime eventDate;
  final List<String> songIds;
  final String createdBy;
  final DateTime? publishedAt;
}

// rehearsal_sessions/{sessionId}
class RehearsalSession {
  final String sessionId;
  final String choirId;
  final String? programId;
  final DateTime date;
  final String time;
  final String location;
  final String directorId;
  final bool isGuestDirector;
  final String? notes;
  final String? guestToken;
  final DateTime? guestTokenExpiry;
}

// attendance/{sessionId_userId}  ← composite document ID
class Attendance {
  final String sessionId;
  final String userId;
  final RSVPStatus rsvp; // enum: coming, not_coming, pending
  final bool attended;
  final VoicePart? voicePartOverride;
}

// listen_events/{eventId}
class ListenEvent {
  final String userId;
  final String audioPartId;
  final String songId;
  final String sectionId;
  final DateTime listenedAt;
  final int durationPlayedSeconds;
  final bool completed;
}

// chat_messages/{messageId}
class ChatMessage {
  final String messageId;
  final String choirId;
  final String senderId;
  final MessageType type; // enum: text, audio, image
  final String content;
  final VoicePart? targetVoicePart; // null = all
  final bool pinned;
  final DateTime timestamp;
}

// subscriptions/{choirId}  ← one per choir
class Subscription {
  final String choirId;
  final ChoirPlan plan;
  final PaymentProvider provider; // enum: mtn, airtel
  final DateTime startDate;
  final DateTime endDate;
  final String txRef;
  final SubscriptionStatus status; // enum: active, expired, pending
}
```

**Composite IDs:** For `choir_memberships`, use `${choirId}_${userId}` as the document ID. For `attendance`, use `${sessionId}_${userId}`.

**Indexes needed** (add to `firestore.indexes.json`):
- `songs` → composite: `choirId ASC, createdAt DESC`
- `rehearsal_sessions` → composite: `choirId ASC, date ASC`
- `chat_messages` → composite: `choirId ASC, timestamp ASC`
- `attendance` → composite: `sessionId ASC, attended ASC`

---

## 7. FIREBASE SECURITY RULES

Implement these rules in `firestore.rules`. These are requirements, not suggestions.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: is user a member of a choir?
    function isMember(choirId) {
      return exists(/databases/$(database)/documents/choir_memberships/$(choirId + '_' + request.auth.uid));
    }

    // Helper: get membership data
    function membership(choirId) {
      return get(/databases/$(database)/documents/choir_memberships/$(choirId + '_' + request.auth.uid)).data;
    }

    // Helper: role check
    function hasRole(choirId, role) {
      return isMember(choirId) && membership(choirId).role == role;
    }

    // Helper: permission check
    function hasPermission(choirId, perm) {
      return isMember(choirId) && (
        membership(choirId).role == 'leader' ||
        membership(choirId).role == 'director' ||
        perm in membership(choirId).permissions
      );
    }

    // USERS: own document only
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }

    // CHOIRS: members can read, only leader can write
    match /choirs/{choirId} {
      allow read: if isMember(choirId);
      allow create: if request.auth != null;
      allow update: if hasRole(choirId, 'leader');
      allow delete: if false; // Never delete choirs
    }

    // MEMBERSHIPS: members can read their choir, only leader can write
    match /choir_memberships/{membershipId} {
      allow read: if isMember(membershipId.split('_')[0]);
      allow create: if request.auth != null; // Joining via invite
      allow update: if hasRole(membershipId.split('_')[0], 'leader');
      allow delete: if hasRole(membershipId.split('_')[0], 'leader');
    }

    // SONGS: members read, directors/uploaders write
    match /songs/{songId} {
      allow read: if isMember(resource.data.choirId);
      allow create, update: if hasPermission(request.resource.data.choirId, 'audio_uploader');
      allow delete: if hasRole(resource.data.choirId, 'leader');
    }

    // AUDIO PARTS: members read, directors/uploaders write
    match /audio_parts/{partId} {
      allow read: if true; // Validated at Song level
      allow write: if request.auth != null; // Validated at Song level — tighten post-beta
    }

    // REHEARSAL SESSIONS: members read, directors/leaders write
    match /rehearsal_sessions/{sessionId} {
      allow read: if isMember(resource.data.choirId);
      allow create, update: if hasRole(resource.data.choirId, 'leader') || hasRole(resource.data.choirId, 'director');
    }

    // ATTENDANCE: members read their own, attendance managers write
    match /attendance/{attendanceId} {
      allow read: if request.auth.uid == resource.data.userId || 
                     hasPermission(resource.data.sessionId, 'attendance_manager');
      allow write: if hasPermission(request.resource.data.sessionId, 'attendance_manager');
    }

    // CHAT: all members can read/write
    match /chat_messages/{messageId} {
      allow read: if isMember(resource.data.choirId);
      allow create: if isMember(request.resource.data.choirId);
      allow update: if hasRole(resource.data.choirId, 'leader') || hasRole(resource.data.choirId, 'director');
    }

    // SONG PROGRAMS: members read, authorized write
    match /song_programs/{programId} {
      allow read: if isMember(resource.data.choirId);
      allow write: if hasPermission(request.resource.data.choirId, 'song_program_planner');
    }

    // LISTEN EVENTS: user writes their own, leaders/directors read all
    match /listen_events/{eventId} {
      allow create: if request.auth.uid == request.resource.data.userId;
      allow read: if request.auth.uid == resource.data.userId; // Extend for Pro analytics
    }

    // SUBSCRIPTIONS: read by choir members, write by Cloud Functions only (Admin SDK)
    match /subscriptions/{choirId} {
      allow read: if isMember(choirId);
      allow write: if false; // Cloud Functions Admin SDK only
    }
  }
}
```

---

## 8. SCREEN IMPLEMENTATIONS

For each screen, the wireframe (`KwayaProApp.jsx`) is the authoritative UI spec. Translate every component to its Flutter Material 3 equivalent. The mapping below is your translation guide.

### 8.1 Shared Widgets

Implement these in `shared/widgets/` before building any screen. All screens depend on them.

| Wireframe component | Flutter widget | Notes |
|---|---|---|
| `<Button variant="filled">` | `FilledButton` | Pill shape (50dp radius), min height 48dp |
| `<Button variant="tonal">` | `FilledButton.tonal` | Same sizing |
| `<Button variant="outlined">` | `OutlinedButton` | 2dp border |
| `<Button variant="text">` | `TextButton` | |
| `<IconButton variant="standard">` | `IconButton` | 48×48dp min tap target |
| `<IconButton variant="filled">` | `IconButton.filled` | |
| `<IconButton variant="tonal">` | `IconButton.filledTonal` | |
| `<Chip>` | `FilterChip` | M3 spec: 32dp height, 8dp border radius |
| `<M3FAB>` | `FloatingActionButton` | 56×56dp, `borderRadius: BorderRadius.circular(16)` |
| `<EmptyState>` | Custom widget | 128×128dp icon container, centered column |
| Snackbar | `ScaffoldMessenger.of(context).showSnackBar()` | Use M3 `SnackBar` |
| Dialog | `showDialog()` with `AlertDialog` | M3 28dp corner radius |

**Skeleton loading:** Use `shimmer` package (add to pubspec: `shimmer: ^3.0.0`). Apply to list items while `AsyncValue.loading`.

### 8.2 Onboarding Flow (6 steps)

Maps to `OnboardingFlow` in the wireframe. Implement as a `StatefulWidget` with a `PageController` (or step `int` state + `AnimatedSwitcher`).

**Steps:**
1. Welcome splash — KwayaPro logo, tagline, "Get Started" button
2. Phone input — `+256` country code prefix, phone field, "Send Code" → triggers `firebase_auth.verifyPhoneNumber()`
3. OTP verification — 6-box OTP input (custom widget), auto-verify on 6th digit entry
4. Profile creation — avatar placeholder (image_picker), name field
5. Join or Create — two large tappable cards; "Join" opens invite code input; "Create" opens choir creation form
6. Voice part selection — four full-width buttons (Soprano/Alto/Tenor/Bass); selection highlighted in `primaryContainer`

**After step 6:** Write `AppUser` doc to Firestore, write `ChoirMembership` doc, navigate to `/home`.

**Deep link join:** If app opened with `/join/:inviteCode`, skip step 5's "Join" card and pre-fill the invite code.

### 8.3 Home Screen

Maps to `HomeScreen`. Role-aware — render different content for Leader, Director, Chorister.

**Hero card:** `primaryContainer` background, rounded 32dp. Shows choir name (tappable → choir switcher bottom sheet), role label, and metric pills (42 Members / 18 Songs / 82% Attend for management; personal attendance % for choristers).

**Choir switcher bottom sheet:** Triggered by tapping choir name. Lists all choirs the user belongs to with their role in each. Active choir shown with `CheckCircle2` icon and `primaryContainer` tint. "Join or Create Another" button at bottom. Switching choir updates `activeChoirProvider`.

**Management quick-actions grid:** Shown only for Leader and Director. Leader sees: Programs, Billing, Manage Members. Director sees: Programs only. Use `FilledButton.tonal` with leading icon.

**Upcoming rehearsal card:** Next `RehearsalSession` from `upcomingRehearsalsProvider`. Shows date badge (month + day in `tertiaryContainer`), title, time, location.

**Continue practicing card:** Last played `AudioPart` from local Hive cache. Shows song title, voice part, section. `IconButton.filled` play button.

**FAB:** Not shown on Home Screen.

### 8.4 Library Screen

Maps to `LibraryScreen`.

**Search bar:** `SearchBar` widget (M3), full-width, rounded-full, filters `songLibraryProvider` by title.

**Filter chips:** Horizontal scroll row — All / Soprano / Alto / Tenor / Bass. Filters audio parts visible on song items. Uses `currentMembershipProvider` to pre-select the user's default voice part.

**Your part banner:** `primaryContainer` strip above song list. Text: "YOUR PART: ALTO — Tap parts to listen". Hidden for Directors who can see all parts.

**Song list items (`SongListItem`):**
- Leading 56×56dp icon in `primaryContainer`/`secondaryContainer`/`tertiaryContainer` (cycle colors)
- Title (truncated), subtitle (category · Key of X)
- Voice part pills row: S / A / T / B. Active user's part = `secondaryContainer` background. Missing parts = `surfaceVariant`. Tap any pill → play that part via `just_audio`
- Trailing `MoreVertical` icon button → bottom sheet with: Edit Song, Delete Song (Leader/Director only), Share

**Freemium gate:** If `choir.plan == free && choir.songCount >= 3`, show upgrade banner above list. Tapping any "Add Song" action triggers `BillingScreen`.

**FAB:** `Plus` icon, visible only for Leader and Director. Opens "Add Song" bottom sheet with two options:
1. Upload audio file (`file_picker`)
2. Record in Studio (navigates to `/studio` with pre-set song context)

### 8.5 Audio Player

When a user taps a voice part pill on a song, initialize `just_audio` `AudioPlayer` with the R2 audio URL. Show a persistent mini-player at the bottom of the Library screen (above the bottom nav) with:
- Song title + voice part label
- `IconButton` play/pause
- Seek bar (`LinearProgressIndicator`, tappable to seek)
- Playback speed selector (0.5×, 0.75×, 1×, 1.25×, 1.5×) — bottom sheet
- Repeat toggle

Log every play event to `listen_events` collection in Firestore (background write, don't block UI).

### 8.6 Rehearsals Screen

Maps to `RehearsalsScreen`.

**Next rehearsal card:** Bordered with `primary` color, left accent strip, "Next" badge. Shows title, date/time, location with `Pin` icon.

**RSVP segmented control:** Three buttons in a `surfaceVariant` pill container: "Going" / "Maybe" / "Can't". Active selection highlighted. Tapping triggers `confirmAction` dialog (as in wireframe), then writes to `attendance` collection.

**Management actions (Director + Leader only):** Two buttons: "Attendance" (`ClipboardCheck` icon → `/attendance/:sessionId`) and "Guest" (`User` icon → `/guest-director/:sessionId`).

**Past rehearsals:** Show below upcoming ones, muted opacity, no RSVP controls.

**FAB:** `Plus` icon, Director + Leader only. Opens "Schedule Rehearsal" bottom sheet: date picker, time picker, location field, director assignment dropdown.

### 8.7 Attendance Screen

Maps to `AttendanceScreen`. Director + Leader access only.

**Header:** Back button, session title, "X/N PRESENT" subtitle. Save `IconButton.filledTonal` (writes batch to Firestore on tap).

**Member list grouped by voice part:** Section headers with member count badge. Each row: checkbox, member name, voice part override button.

**Attendance toggle:** Tap row → toggle `attended` bool. Present = `secondaryContainer` background + filled checkbox.

**Voice part override bottom sheet:** Triggered by tapping the voice part badge (e.g. "A▾") on any row. Lists all four voice parts. Current part highlighted. Selecting a different part writes `voicePartOverride` to the `attendance` document with an informational note: "This assignment applies to this rehearsal only."

### 8.8 Chat Screen

Maps to `ChatScreen`.

**Header:** Choir avatar, choir name, online member count (static for MVP: "X members online"), `MoreVertical` options button.

**Pinned message banner:** `primaryContainer` background, left `primary` accent strip, `Pin` icon, message text, `Share2` icon button (→ WhatsApp share via `share_plus`).

**Messages list:** `StreamProvider` Firestore stream rendered in a `ListView.builder`. Messages from other users: left-aligned, `surfaceVariant` bubble. Own messages: right-aligned, `secondaryContainer` bubble.

**Voice part targeting (Director + Leader):** "To: All ▾" pill above the input bar. Tap → bottom sheet with All / Soprano / Alto / Tenor / Bass. Selected target displayed on sent message as a small chip.

**Input bar:**
- Text field in `surfaceVariant` pill
- Voice note button: tap → recording state (red waveform + timer + Trash icon to cancel). Tap send → uploads to Firebase Storage, posts `ChatMessage` with `type: audio`.
- Send button: `IconButton.filled`

**Image attachment:** Long-press text field or `+` button (implement if scope allows, can defer to polish week).

### 8.9 Studio Screen (Landscape Lock)

Maps to `StudioLandscapeScreen`. This is the most complex screen. **Lock to landscape on entry, restore portrait on exit.**

```dart
// Lock orientation on enter
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

// Restore on dispose
@override
void dispose() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  super.dispose();
}
```

**Layout:** Two panes stacked vertically. Top pane = controls (3-column layout). Bottom pane = scrollable piano keyboard (150dp height).

**Top pane — Left column (260dp):**
- Back button + "Studio" title + Settings icon
- Context card: song title, key, section label, voice part segmented control (S/A/T/B initials)

**Top pane — Center column (flex):**
- Idle state: pitch tuner gauge SVG (from wireframe) with needle idle animation
- Recording state: red waveform bars with `wave` animation + timer + "RECORDING" label
- Record button: idle = wide pill `FilledButton` ("RECORD ALTO" + `Mic2` icon); recording = circular red `IconButton` (`Square` icon)
- On stop → auto-upload to R2 via presigned URL, show upload progress, on success → write `AudioPart` to Firestore, show Snackbar "Saved."

**Top pane — Right column (260dp):**
- Metronome BPM display (`OutlinedButton`, non-interactive for MVP — tap opens BPM picker)
- Sustain button: full-width, `tertiaryContainer` when active, `surfaceVariant` when inactive

**Piano keyboard (bottom pane):**
- `SingleChildScrollView(scrollDirection: Axis.horizontal)` containing a `Stack` of white and black keys
- White keys: `56dp` wide, full height, rounded bottom corners, note name label at bottom
- Black keys: `32dp` wide, 62% height, `Color(0xFF2A251D)`, rounded bottom, positioned at correct offsets using the math from the wireframe comment: `left = (index + 1) / numKeys * totalWidth - 16`
- Octave scroll buttons: left and right arrows overlaid with gradient fade, scroll `ScrollController` by `392px` per tap (7 white keys × 56dp)
- Auto-scroll to correct octave when voice part changes (Soprano: C4, Alto: G3, Tenor: C3, Bass: E2)
- Tapping a key plays a note via `just_audio` from a local asset bundle of piano note samples (include 2 octaves of piano samples as `assets/audio/piano/`)

**External file upload path:** Accessible from Library screen's "Add Song" FAB → `file_picker` → select MP3/WAV/M4A/AAC → upload to R2 → write `AudioPart`. This is an alternative to the in-app recording path; both produce identical Firestore records.

### 8.10 Program Planner Screen

Maps to `PlannerScreen`. Access: Leader, Director, any chorister with `song_program_planner` permission.

**Event details section:** Text field for event name, event type chip row (Mass / Wedding / Concert / Rehearsal / Other), date picker.

**Song order list:** `ReorderableListView`. Each item shows: drag handle (`GripVertical`), order number circle, song title, event type label, missing audio warning badge (`AlertCircle` + "Missing Tenor audio" in `errorContainer`).

**Publish/Draft:** Bottom action bar with "Save Draft" (`OutlinedButton`) and "Publish" (`FilledButton` + `Share2` icon). On publish → set `publishedAt` timestamp in Firestore → trigger FCM to all choir members.

### 8.11 Members & Permissions Screens

Maps to `MembersScreen` + `MemberDetailScreen`. Leader-only access.

**Members screen:** Grouped by management team vs choristers. Each chorister row shows name, voice part, permission chip badges (e.g. "Song Planner"), chevron → `MemberDetailScreen`.

**Member detail screen:** Avatar, name, role label. Permission toggles (`Switch` widgets) for: Song Program Planner / Audio Uploader / Score Librarian. Toggling a switch writes the `permissions` array to the `ChoirMembership` document immediately. Remove from Choir button (destructive confirm dialog → deletes `ChoirMembership` doc, preserves attendance history).

### 8.12 Guest Director Screen

Maps to `GuestDirectorScreen`. Leader-only access, opened from Rehearsals screen.

**Generates a one-time token:** Write a `guestToken` (UUID v4) and `guestTokenExpiry` (rehearsal end time) to the `RehearsalSession` document. Construct a deep link: `https://kwayapro.page.link/rehearsal-invite/{token}`. Share via `share_plus`.

**Permissions summary card:** List of what guest director can and cannot do (from PRD section 4.1).

**Expiry note:** "Auto-expires when session ends" in `errorContainer` styling.

### 8.13 Billing Screen

Maps to `BillingScreen`. Leader-only access.

**4-step flow (match wireframe states exactly):**
1. Upgrade prompt — feature list, UGX 40,000/month pricing, "Upgrade Now" button
2. Payment method selection — MTN MoMo card (yellow #FFCC00, black text) + phone input
3. Waiting for payment — M3 circular progress indicator, "Check Your Phone" message
4. Success — green checkmark, transaction summary card (Amount / Transaction ID / Valid Until)

**Backend call (Week 5-6):** From step 2, call your Cloud Function endpoint that initiates the MTN MoMo Collections API request. Poll (or use FCM) for webhook confirmation. On confirmation, `Subscription` doc in Firestore is updated by Cloud Function. `choirSubscriptionProvider` stream auto-refreshes UI.

**MVP placeholder:** During weeks 1-4, the billing screen can simulate the flow without a live Cloud Function call. Wire the real API in Week 5.

### 8.14 Profile Screen

Maps to `ProfileScreen`.

**Avatar:** Initials fallback (first letter of first + last name). Tap → `image_picker` → upload to Firebase Storage → update `profilePhotoUrl` in Firestore user doc.

**Dark mode toggle:** `Switch` → writes preference to `SharedPreferences` → applies `ThemeMode.dark` to `MaterialApp`.

**Empty States toggle:** Debug-only flag. Hide in release builds (`kReleaseMode` check).

**Role switcher:** Debug-only. Remove in release builds.

**Sign Out:** Destructive confirm dialog → `firebase_auth.signOut()` → navigate to `/onboarding`.

---

## 9. CLOUDFLARE R2 AUDIO UPLOAD

### 9.1 Presigned URL flow

The mobile client never has direct R2 credentials. The flow:

1. Flutter calls your Cloud Function endpoint `POST /api/audio/presigned-url` with `{ choirId, songId, sectionId, voicePart, mimeType }`
2. Cloud Function generates a presigned URL using R2 S3-compatible API (valid for 15 minutes)
3. Flutter uploads the audio file directly to R2 using `http` package `PUT` request with the presigned URL
4. On upload success (HTTP 200), Flutter calls Cloud Function `POST /api/audio/confirm` with the R2 object key
5. Cloud Function writes the `AudioPart` document to Firestore (or Flutter writes it directly after confirming upload)

### 9.2 Object key naming convention

```
choirs/{choirId}/songs/{songId}/sections/{sectionId}/{voicePart}.{ext}
```

Example: `choirs/abc123/songs/def456/sections/ghi789/A.m4a`

### 9.3 Audio upload progress

Use Flutter `http` package with a `StreamedRequest` to show real-time upload progress. Drive a `LinearProgressIndicator` in the Studio screen during upload.

### 9.4 MVP shortcut (Week 1-3)

If R2 Cloud Functions are not yet deployed, temporarily upload audio to Firebase Storage and store that URL in `AudioPart.audioUrl`. Replace with R2 presigned URLs in Week 3.

---

## 10. PUSH NOTIFICATIONS — FCM

### 10.1 Init

Initialize `firebase_messaging` in `main.dart`. Request permissions on first launch (after onboarding, not before). Store `fcmToken` in the user's Firestore document.

### 10.2 Background handling

```dart
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

Use `flutter_local_notifications` to display notifications when app is in foreground.

### 10.3 Notification types to handle

| Trigger | Sent by | Payload |
|---|---|---|
| New rehearsal scheduled | Cloud Function | `{ type: 'rehearsal_created', sessionId, choirId }` |
| New audio uploaded | Cloud Function | `{ type: 'audio_uploaded', songId, voicePart, choirId }` |
| Rehearsal 24hr reminder | Cloud Function (scheduled) | `{ type: 'rehearsal_reminder', sessionId }` |
| Song program published | Cloud Function | `{ type: 'program_published', programId, choirId }` |
| New chat message | Cloud Function | `{ type: 'chat_message', choirId }` |

### 10.4 Navigation on tap

Use `go_router` to navigate to the relevant screen when a notification is tapped:
- `rehearsal_created` → `/home/rehearsals`
- `audio_uploaded` → `/home/library`
- `program_published` → `/planner`
- `chat_message` → `/home/chat`

---

## 11. INVITE & DEEP LINK SYSTEM

### 11.1 Invite code generation

When a choir is created, generate a 6-character alphanumeric invite code (store in `Choir.inviteCode`). Also generate a shareable link:
```
https://kwayapro.page.link/join/{inviteCode}
```

### 11.2 Join flow (deep link handler)

In `go_router`, handle `/join/:inviteCode`:
1. If user is not authenticated → complete onboarding → auto-redirect to join flow with code pre-filled
2. If authenticated → query Firestore for choir with matching `inviteCode` → show choir name + "Join Choir" confirmation → create `ChoirMembership` doc

### 11.3 Guest director deep link

`/rehearsal-invite/:token`:
1. Validate token against `RehearsalSession.guestToken` and `guestTokenExpiry`
2. If valid → create temporary `ChoirMembership` with `role: director` scoped to this session
3. Navigate to `RehearsalsScreen` with the session active

---

## 12. OFFLINE SUPPORT

### 12.1 Firestore offline persistence

Already covered in section 5. All `StreamProvider` Firestore streams will auto-serve from cache when offline.

### 12.2 Audio caching

When a user plays an audio part, cache the file locally using `path_provider`. On subsequent plays, serve from cache if available, otherwise stream from R2. Store cache metadata (URL → local path mapping) in Hive.

### 12.3 Attendance offline queue

Attendance marking must work offline. If `connectivityProvider` detects no network, queue the write using Firestore's offline pending write queue (built-in). Show a `surfaceVariant` banner: "You're offline — attendance will sync when reconnected."

---

## 13. SPRINT SCHEDULE

Implement in this order. Do not build Week 4 features before Week 2 is functionally complete.

### Week 1 — Foundation
- [ ] Flutter project bootstrapped, FlutterFire configured
- [ ] M3 theme with all color tokens applied
- [ ] go_router with all routes defined
- [ ] Onboarding flow (all 6 steps) with Firebase Auth phone OTP
- [ ] Firestore `User` and `Choir` writes on signup
- [ ] Choir create flow (name, church, cover photo upload to Firebase Storage)
- [ ] Invite code generation and shareable link
- [ ] Choir join flow via invite code (deep link handler)
- [ ] Voice part assignment on join
- [ ] `ChoirMembership` document creation
- [ ] Home screen (all role states: Leader, Director, Chorister)
- [ ] Bottom navigation shell with SharedAxisTransition

**Acceptance:** User can create a choir, share the invite link, and a new device can install the app, join via the link, select a voice part, and see the Home screen with correct role.

### Week 2 — Song Library
- [ ] Song creation (title, key, language, category)
- [ ] Song section creation (Verse / Chorus / Bridge + custom)
- [ ] External audio file upload via `file_picker` → Firebase Storage (R2 in Week 3)
- [ ] `AudioPart` Firestore document creation
- [ ] Library screen with real Firestore data
- [ ] Voice part filter chips (functional)
- [ ] `just_audio` playback from audio URL
- [ ] Mini audio player bar
- [ ] Listen event logging to Firestore
- [ ] Freemium 3-song limit enforcement (check `choir.songCount >= 3` before `AudioPart` upload)
- [ ] Upgrade prompt on 4th song attempt

**Acceptance:** Director uploads an audio file to a song section. Chorister sees audio for their voice part. 4th upload triggers upgrade prompt. Play logs a `ListenEvent`.

### Week 3 — Recording Studio
- [ ] Studio screen with landscape lock
- [ ] Piano keyboard (scrollable, white + black keys, correct octave layout)
- [ ] Octave scroll buttons
- [ ] Voice part selector (auto-scrolls keyboard to correct range)
- [ ] `record` package integration — record audio from mic
- [ ] Pitch indicator (live VU meter via audio level stream from `record`)
- [ ] Metronome (BPM-adjustable click track using `just_audio` with looping metronome tick asset)
- [ ] Sustain button (repeat note on key hold via `just_audio`)
- [ ] R2 presigned URL upload pipeline (replace Firebase Storage for audio)
- [ ] `AudioPart` Firestore write on save
- [ ] Push notification to voice part choristers on new audio upload

**Acceptance:** Director records an Alto part using the virtual keyboard for pitch reference. Pitch indicator shows live feedback. Audio uploads to R2. Choristers receive push notification.

### Week 4 — Rehearsal Management
- [ ] Rehearsal creation (date, time, location, director assignment)
- [ ] Rehearsals screen with real Firestore data
- [ ] RSVP flow (Going / Maybe / Can't → Attendance doc write)
- [ ] Push notification on rehearsal creation
- [ ] 24-hour reminder notification (via Cloud Function scheduled trigger)
- [ ] Guest director one-time link generation
- [ ] Guest director join flow via deep link
- [ ] Guest `ChoirMembership` creation with session scope
- [ ] Auto-expiry of guest permissions (Cloud Function triggered on session end time)

**Acceptance:** Leader schedules a rehearsal, assigns a guest director. Guest taps link → joins rehearsal. Permissions are scoped to the session and auto-expire.

### Week 5 — Attendance, Planner, Scores
- [ ] Attendance marking screen (grouped by voice part, checkboxes, batch write)
- [ ] Voice part override per session
- [ ] Attendance history per chorister (self-visible)
- [ ] Song program creation and publish flow
- [ ] Song program push notification on publish
- [ ] Score PDF/image upload (Firebase Storage)
- [ ] Members & permissions management screens
- [ ] Dashboard metrics card (members, songs, attendance %)
- [ ] Granular permission toggles (functional writes to `ChoirMembership.permissions`)

**Acceptance:** Director marks attendance with voice part overrides. Committee member with `song_program_planner` permission can create and publish a program. Leader can toggle granular permissions for any chorister.

### Week 6 — Chat, Payments, Polish
- [ ] Choir chat screen with real Firestore stream
- [ ] Text message send/receive
- [ ] Voice note recording in chat (Firebase Storage upload)
- [ ] Pinned message functionality
- [ ] Voice part targeting for messages
- [ ] WhatsApp cross-post (`share_plus`)
- [ ] MTN Mobile Money payment flow (Cloud Function integration)
- [ ] Airtel Money fallback
- [ ] `Subscription` Firestore doc update via webhook
- [ ] `choirSubscriptionProvider` real-time unlock
- [ ] Dark mode (full theme switch)
- [ ] Error states (all `AsyncValue.error` handled)
- [ ] Performance: audio playback within 2s on 4G
- [ ] APK build via `flutter build apk --release`
- [ ] Firebase App Distribution beta deploy to test choirs

**Acceptance:** Full payment flow end-to-end. Choir chat functional. WhatsApp share works. APK installs and runs on a physical Android device in Uganda.

---

## 14. DEFINITION OF DONE

The build is complete when ALL of the following pass on a physical Android device:

- [ ] Cold start < 3 seconds on 2GB RAM device
- [ ] Auth flow works on physical device with real Ugandan phone number
- [ ] Choir create → invite → join → voice part → library → play audio (full chorister flow)
- [ ] Director records in-app audio → uploads → chorister hears it → listen event logged
- [ ] Guest director link generates → works → auto-expires
- [ ] Attendance marking with voice part override persists to Firestore
- [ ] MTN payment flow triggers real MoMo prompt (use test credentials)
- [ ] 4th song upload blocked on free tier → upgrade prompt appears
- [ ] Chat sends and receives text + voice notes
- [ ] WhatsApp share button opens native share sheet
- [ ] App works offline (Library playback cached, attendance marking queued)
- [ ] Firestore Security Rules block all cross-choir data access (run `firebase emulators:exec` test suite)
- [ ] All screens accessible via keyboard navigation (no focus traps)
- [ ] APK < 50MB install size
- [ ] No fatal crashes in `firebase crashlytics` after 24h beta run

---

## 15. ENVIRONMENT CONFIGURATION

Store all secrets in `.env` (never commit) and access via `flutter_dotenv` package. Required variables:

```
FIREBASE_PROJECT_ID=
R2_BUCKET_NAME=
R2_ACCOUNT_ID=
R2_PRESIGN_FUNCTION_URL=
MTN_MOMO_FUNCTION_URL=
AIRTEL_MONEY_FUNCTION_URL=
DEEP_LINK_DOMAIN=kwayapro.page.link
```

Firebase config goes in `google-services.json` (Android) — generate from Firebase Console. Do not commit this file; add to `.gitignore`. Inject via CI/CD secret in GitHub Actions.

---

## 16. WHAT NOT TO BUILD IN PHASE 1

Explicitly out of scope. Do not implement:

- iOS build (same Dart codebase, Phase 2 only)
- Choir finances module
- Instrumentalist role
- Full SATB mix audio (all 4 parts playing simultaneously)
- Cue voice during rests (Phase 2 studio feature)
- Audition management
- Video recording or distribution
- Pronunciation guide
- Analytics dashboard (Pro listen tracking reads — data is logged, UI is Phase 2)
- Annual billing option

---

*KwayaPro · Built for African Church Choirs · Uganda → East Africa*  
*Phase 1 MVP · Android First · 6-Week Sprint*
