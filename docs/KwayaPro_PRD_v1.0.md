**KWAYAPRO**  ·  Product Requirements Document  ·  MVP v1.0  ·  Confidential

**KWAYAPRO**

*Choir Management Platform*

**Product Requirements Document**

*Version 1.0  ·  MVP Release*

April 2026

| **Product** **KwayaPro** | **Market** **Uganda → East Africa** |
| --- | --- |
| **Author** **Simon Peter Kyagulanyi** | **Status** **Pre-Sprint — Research Validated** |
| **Tech Stack** **Flutter · Firebase · Cloudflare R2** | **Sprint Duration** **6 Weeks · Android First** |

*Confidential — Internal Use Only*

# 1. Executive Summary

KwayaPro is a choir management platform purpose-built for African church choirs. It addresses the specific operational realities of choirs in Uganda and East Africa, where the majority of choristers learn music by ear, keyboards are often unavailable during practice, rehearsal attendance is inconsistent, and all choir coordination currently happens through fragmented WhatsApp groups.

Existing choral software (SmartMusic, Groupanizer, ChoirGenius) is designed for Western, notation-literate choirs. None of them address the African church choir context. KwayaPro is built from the ground up for this underserved market.

The product is conceived by Simon Peter Kyagulanyi, a practicing choir director, pianist, and software developer based in Uganda, giving the product rare insider credibility: the builder is the target user.

## 1.1 Problem Statement

Research interviews with 6 choir directors and leaders across Uganda revealed three primary pain points experienced universally:

- 80% of choristers cannot read music notation and must be taught entirely by ear, requiring directors to repeat the same content for each new or absent member.

- Rehearsal attendance is chronically inconsistent due to economic pressures, transport challenges, and work schedules, making it impossible to build on previous sessions reliably.

- Voice part audio recordings are distributed manually via WhatsApp, with no structure, no accountability, and no guarantee that choristers actually listen before rehearsal.

## 1.2 Solution

KwayaPro provides a unified platform where:

- Every song in a choir's library is permanently stored with per-voice-part audio recordings and sheet music attachments, accessible to all members at any time, including late joiners.

- Rehearsal scheduling, RSVP, attendance tracking, and push notifications replace ad-hoc WhatsApp coordination.

- An in-app recording studio with a virtual keyboard, pitch indicator, and metronome allows directors to record voice parts directly from their phone, no external equipment required.

- A granular permission system reflects how choirs actually operate, with committees, guest directors, and members holding specific administrative responsibilities.

## 1.3 Business Model

| **Tier** | **Price** | **What's included** |
| --- | --- | --- |
| Free | UGX 0 | Up to 3 songs · Unlimited members · Rehearsal scheduling · Choir chat |
| Pro | ~UGX 40,000/month | Unlimited songs · Score library · Program planner · Practice analytics · Priority support |

Payment is collected via MTN Mobile Money and Airtel Money, the two dominant mobile payment providers in Uganda, eliminating the card payment barrier entirely.

## 1.4 Success Metrics – MVP

| **Metric** | **Target (Month 3)** |
| --- | --- |
| Active choirs on platform | 30+ (Peter's direct network) |
| Pro tier conversion | 25% of active choirs |
| Weekly active chorister rate | >60% of enrolled members |
| Audio uploads per choir (Month 1) | ≥3 songs with SATB parts |
| Churn rate (Pro) | <10% monthly |

# 2. Market Context & Research Findings

## 2.1 Target Market

KwayaPro targets African church choirs as its primary market, starting with Uganda and expanding to Kenya, Tanzania, Rwanda, and Ghana in subsequent phases. The characteristics that define this market are distinct from Western choral contexts:

- The majority of choristers are musically untrained and learn entirely by ear.

- Choirs are largely voluntary, with members balancing work, family, and transport constraints.

- Most coordination happens through WhatsApp, the de facto communication infrastructure in Uganda.

- Smartphones (primarily Android) are widespread; laptops are not.

- Mobile money (MTN MoMo, Airtel Money) is the dominant payment method, bank cards are rare.

- Church choirs are deeply socially embedded, choir membership carries identity, community, and spiritual significance beyond just music.

## 2.2 Research Methodology

Primary research was conducted using a 12-question Mom Test-compliant questionnaire grounded in The Mom Test (Rob Fitzpatrick) and Questions Are the Answers (Alan Pease). The questionnaire asked exclusively about past behavior, not hypothetical opinions, to surface real pain rather than aspirational responses.

6 choir directors and leaders completed the questionnaire. Respondent profiles:

| **Respondent** | **Experience** | **Choir size** | **Context** |
| --- | --- | --- | --- |
| Ssempijja Alex | 5+ years | Multiple choirs | Mixed working/volunteer, multi-choir director |
| Vincent Katende | 20 years | ~50 members | St Agnes Catholic parish choir |
| Anthony Kambugu | 25+ years | 20–100+ | Schools + parishes, multiple choir types |
| Michael Ddumba (Coro Celeste) | 4 years | ~25 members | Catholic parish, Mulago |
| Kyalimpa John Leonard | 7 years | ~25 (12 active) | Charismatic worship team, Ntinda |
| Andrew Nsubuga | 8 years | 13 active | Parish choir |

## 2.3 Key Research Findings

### Confirmed pain points (100% of respondents)

- All 6 respondents use WhatsApp groups as their primary, and often only, choir management tool.

- All 6 cited attendance inconsistency as a significant and ongoing challenge with no effective solution.

- All 6 rely on informal phone recordings during rehearsal for members to revise at home, with no structured distribution system.

### Confirmed pain points (majority of respondents)

- 4 of 6 respondents cited lack of a keyboard as a blocker, either for pitch reference, accidental notes, or starting note for voices. Direct quote: 'The most important logistics for a rehearsal are the music copies and the keyboard.'

- 4 of 6 cited accidentals and key modulation as the hardest technical challenge in teaching songs.

- 3 of 6 described member inconsistency creating a cycle where the same material must be re-taught to different people each session.

### New pain points surfaced by research

- No music library management: Respondent 6 stated directly, 'My choir doesn't have a librarian and looking for music copies for rehearsal takes time.' Physical and digital scores are scattered across WhatsApp chats, phone cameras, and printed paper.

- Song program planning as a committee function: Respondent 5 described a formal Song Committee of two members who select and plan song programs for upcoming events weeks in advance. This is not a director function, it is delegated to specific members.

- Choir finances are an unaddressed burden: Multiple respondents described weekly member contributions, remuneration of instrumentalists, and event costs as significant administrative work with no dedicated tool.

- Discipline and commitment as a time drain: 3 of 6 respondents identified managing adult member behavior, not music teaching, as their single most time-consuming task.

- Foreign language pronunciation: 2 respondents cited teaching Latin and unfamiliar-language text alongside music notes as compounding the difficulty of new song teaching.

# 3. Product Scope

## 3.1 Platforms

| **Platform** | **Phase** | **Notes** |
| --- | --- | --- |
| Android (Flutter) | MVP – Phase 1 | Primary platform. Google Play Store distribution. Material 3 UI. |
| iOS (Flutter) | Phase 2 | Same Dart codebase as Android. Cupertino adaptive widgets. App Store. |
| Web Dashboard (Next.js 14) | MVP (Admin) | Optional desktop supplement for bulk uploads, analytics, member management. Firebase App Hosting. |

| **NOTE** | The web dashboard is optional, not required. Every feature available on the dashboard must also be fully accessible from the mobile app, because not every choir leader or director has access to a laptop. |
| --- | --- |

## 3.2 Monetization Scope

The freemium model is enforced at the choir level, not the individual user level. Choristers are always free. The paying customer is the Choir Leader.

| **Feature** | **Free** | **Pro** |
| --- | --- | --- |
| Song library (audio parts) | 3 songs | Unlimited |
| Choir members | Unlimited | Unlimited |
| Rehearsal scheduling + RSVP | Yes | Yes |
| Choir chat | Yes | Yes |
| Attendance tracking | Yes | Yes |
| Score/sheet music library | No | Yes |
| Song program planner | No | Yes |
| Practice accountability (listen tracking) | No | Yes |
| Targeted voice-part notifications | No | Yes |
| Attendance analytics dashboard | No | Yes |

## 3.3 Out of Scope – MVP

The following are explicitly deferred to Phase 2 or later to protect sprint scope:

- Choir finances module (member contributions, expense tracking, instrumentalist remuneration)

- Instrumentalist role (keyboard player, drummer, bassist as distinct permission set)

- Full SATB mix audio player (practicing voice prominent, others soft)

- Cue voice during rests (lead voice plays softly during practicing voice's rest)

- iOS build and App Store distribution

- Pronunciation guide per song (phonetic notes or audio for foreign-language text)

- Audition management system

- Concert and event planning beyond basic song programs

- In-app video recording or video distribution

# 4. User Roles & Permission System

KwayaPro uses a two-tier permission model: fixed roles that define a member's base access, and granular permissions that can be granted by the Choir Leader to any member regardless of role.

| **KEY INSIGHT** | Roles in KwayaPro are per choir, not global. A user can be a Choir Leader in Choir A and a regular Chorister in Choir B simultaneously. This reflects real-world choir dynamics where directors and leaders participate in multiple choirs in different capacities. |
| --- | --- |

## 4.1 Fixed Roles

### Choir Leader

One per choir. The administrative owner of the choir. Typically the person who founded or manages the choir at the church level, not necessarily the musical director.

- Creates and manages the choir profile

- Invites and removes members

- Assigns and manages directors (including guest director invitations)

- Manages subscription and billing

- Grants and revokes granular permissions for any member

- Has all permissions always active, no restrictions

- This role cannot be revoked or delegated to another member

### Director

Session-based musical lead. A director is not permanently attached to a choir, they are invited per rehearsal session. A choir can have multiple directors across different sessions. A director can work with multiple choirs.

- Accepts rehearsal invitations (permanent or guest via one-time link)

- Leads musical training during rehearsal sessions

- Uploads voice part audio to the song library

- Overrides a chorister's default voice part for a specific session

- Marks attendance

- Posts choir announcements

- Guest director permissions are scoped to a specific session and auto-expire when the session ends

### Chorister

Default role for all choir members. Choristers frequently sing in multiple choirs and may sing different voice parts depending on the choir's needs in a given session.

- Listens to voice part audio for their assigned or overridden voice part

- RSVPs to rehearsals

- Participates in choir chat

- Views choir dashboard metrics (their own attendance history, upcoming rehearsals, song library)

- Can be assigned additional granular permissions by the Choir Leader

## 4.2 Granular Permissions

Any chorister can be granted specific feature access by the Choir Leader. This reflects real choir structures, song committees, librarians, welfare coordinators, that do not fit neatly into Leader/Director/Chorister categories.

| **Permission key** | **Feature unlocked** | **Research validation** |
| --- | --- | --- |
| song_program_planner | Create & publish event song programs | Respondent 5 described a formal 2-member Song Committee. Respondent 6 plans Sunday Mass programs weekly. |
| score_librarian | Upload & manage score PDFs/images per song | Respondent 6: 'My choir doesn't have a librarian, looking for music copies takes time.' |
| audio_uploader | Upload voice part audio to song library | Needed for guest directors and any appointed member who records parts externally. |
| attendance_manager | Mark attendance & view full history | Some choirs designate a welfare or secretary member to track records. |
| announcements | Post pinned announcements & send targeted push to voice parts | Respondent 5 has a coordinator who manages all outgoing choir communication. |

| **GUARDRAIL** | Only the Choir Leader can grant or revoke granular permissions. Directors cannot delegate permissions to choristers. Member management and billing are always Leader-only and are never delegatable under any circumstance. |
| --- | --- |

# 5. Feature Specifications

## 5.1 Authentication & Onboarding

### User registration

- Phone number + OTP as the primary authentication method (most reliable in Uganda)

- Email + password as fallback

- Google Sign-In as optional third path

- Single account supports membership in multiple choirs with different roles

### Choir join flow

- Choir Leader shares an invite code or deep link (via WhatsApp or any channel)

- New member taps link → app opens (or prompts install) → account created → auto-joined to choir

- Member selects their default voice part (Soprano, Alto, Tenor, Bass) on first join

- Member immediately sees the full song library filtered to their voice part

## 5.2 Choir & Member Management

### Choir profile

- Choir name, church/parish name, cover photo

- Plan indicator (Free / Pro) with song count remaining on free tier

- Member count and voice part distribution visible to all members

### Member management (Choir Leader only)

- View full member list with voice parts and roles

- Change a member's default voice part

- Grant or revoke granular permissions

- Remove a member from the choir

- View members who belong to multiple choirs (flagged for awareness, not restricted)

## 5.3 Song Library

The song library is permanent and choir-specific. Every song ever uploaded by the choir remains in the library, organized by sections and voice parts. A new member who joins after a song was learned can immediately access all audio for their voice part without any action by the director.

### Song structure

- Song (title, key, language, category, uploadedBy)

- Song Sections (Verse, Chorus, Bridge, or custom labels like Part 1, Part 2)

- Audio Parts per section (Soprano, Alto, Tenor, Bass) - each an independent upload

- Score Attachments per song (PDF or image of sheet music) - Pro tier

### Upload paths

- Path A — In-app recording: Director records directly inside KwayaPro using the built-in recording studio (see Section 5.6). Audio uploads to Cloudflare R2 on save.

- Path B — External upload: Director uses file_picker to select an existing audio file (MP3, WAV, M4A, AAC) from phone storage or cloud. Same R2 destination, identical chorister experience.

### Chorister audio player

- Chorister sees only audio for their assigned or overridden voice part by default

- Section status displayed: Ready (audio uploaded) or Coming Soon (not yet available)

- Simple player: play, pause, seek, repeat, playback speed control

- Every play event is logged to ListenEvent collection for practice accountability (Pro)

- Free tier: first 3 songs fully functional. On 4th song upload attempt, upgrade prompt appears.

## 5.4 Rehearsal Management

### Scheduling

- Director or Leader creates a rehearsal: date, time, location, notes, optional song program attachment

- Assigns a director to the rehearsal (can be changed up to the session start)

- Push notification sent to all choir members on rehearsal creation

### RSVP

- Choristers RSVP: Coming / Not Coming / No response (default)

- Director sees RSVP summary before rehearsal: 'Coming: 14 · Not coming: 3 · No response: 5'

- RSVP deadline can be set by director

- Push reminder sent 24 hours before rehearsal to members who have not RSVPed

### Guest director invitation

- Leader opens rehearsal → Change Director → Invite via link

- Cloud Function generates a one-time, time-limited token and deep link

- Link shared via WhatsApp (share_plus native share sheet)

- Director taps link → joins rehearsal → granted temporary director permissions scoped to that sessionId

- Guest director access: member list, voice parts, audio library, attendance marking, audio upload

- Guest director cannot access: choir admin settings, member management, billing

- On rehearsal end: Cloud Function scheduled trigger automatically expires all guest permissions

## 5.5 Attendance Tracking

### Marking attendance

- Director opens attendance screen on rehearsal day, sees member list with RSVP status

- Taps each present member to mark as attended

- Supports batch: 'Mark all who RSVPed Coming as Attended' for efficiency

- Voice part override: Director can assign a different voice part to a specific chorister for this session (e.g. move an Alto to Tenor if Tenor section is weak)

### Attendance history

- Each chorister sees their own personal attendance history and percentage

- All members see overall choir attendance metrics on the choir dashboard

- Director/Leader sees full per-member attendance history (Pro: detailed analytics)

- Visibility of attendance data creates accountability without requiring the director to confront individual members

## 5.6 Recording Studio

The recording studio is accessible to directors and any member with the audio_uploader permission. It provides two paths: in-app recording and external file upload. Both paths produce identical results for the chorister.

### In-app recording flow

- Director opens a song → selects a section (e.g. Chorus) → selects voice part (e.g. Alto)

- Recording screen opens in landscape lock - keyboard, metronome, and pitch indicator visible

- Director selects song key → app plays the Alto starting note automatically

- Director can tap sustain button on the virtual keyboard to hear accidental notes before singing

- Director taps Record → sings the part → live pitch indicator shows real-time feedback

- Director taps Stop → reviews → saves → audio uploads to Cloudflare R2 → section marked Ready

- Push notification sent to all Alto choristers: 'New audio uploaded for Chorus - Alto part'

### Virtual keyboard specification

| **Property** | **Specification** |
| --- | --- |
| Display orientation | Always landscape, screen auto-locks on keyboard open, returns to portrait on close |
| Key range shown | User-selectable: 1 octave (larger keys) or 2 octaves (wider range). Full piano range accessible via octave shift buttons ◀ ▶ |
| Voice auto-range | Soprano: C4–C6 · Alto: G3–G5 · Tenor: C3–C5 · Bass: E2–E4. Keyboard auto-jumps to the correct range when voice part is selected. |
| Sustain button | Note continues ringing after finger is lifted. Essential for accidentals — director taps the note, hears it sustain, then finds the pitch vocally before recording. |
| Pitch indicator | Live visual tuner shown during recording. Green = in tune. Red = off pitch. Director can self-correct in real time. |
| Metronome | BPM-adjustable click track. Plays during voice rests so choristers can count bars and re-enter at the correct point. |
| Global access | Floating button on every screen in the app, including pre-login. Available offline. Multiple phones can use simultaneously. No choir context required. |

| **RESEARCH VALIDATION** | 4 of 6 research respondents cited the lack of a physical keyboard as a direct rehearsal blocker. Respondent 6: 'The most important logistics for a rehearsal are the music copies and the keyboard.' Respondent 5: 'Lack of a keyboard for our practices at the parish center' listed as a top-3 hardest problem. |
| --- | --- |

### Rest point handling

- MVP: Click track (metronome) plays during a voice part's rest so the chorister counts bars and knows when to re-enter.

- Phase 2: Cue voice - a soft lead voice plays during the resting part's silence for musical reference.

- Phase 2: Full SATB mix - all four parts combined, practicing voice prominent, others soft.

## 5.7 Song Program Planner

The song program planner allows authorized members to create and publish event-specific song programs. This was validated by research as a function frequently delegated to a committee rather than handled solely by the director.

### Access

- Choir Leader (always)

- Director (always)

- Any chorister granted the song_program_planner permission by the Choir Leader

### Program creation flow

- Member opens Programs tab → Create New Program

- Enter event name (e.g. 'Sunday Mass - 4th May'), select event type (Mass / Wedding / Concert / Rehearsal / Other), set event date

- Add songs from the choir's library → reorder by drag to set performance order

- Mark program as Draft (visible to admins only) or Published (visible to all members)

- On publish: push notification sent to all choir members - 'Sunday Mass program published. Check what to practice.'

- All members open Programs tab → see the full song list → know exactly what to practice before the event

### Rehearsal attachment

- A program can be optionally attached to a scheduled rehearsal

- When director opens the rehearsal, the program is displayed as the agenda

- Director can add session notes alongside the program

## 5.8 Choir Chat

Every choir has a persistent group chat that all members are automatically joined to on enrollment. The choir chat is the in-app alternative to WhatsApp groups, not a replacement, but a structured supplement.

### Message types

- Text messages

- Voice note recordings (mic recording within the app → Firebase Storage)

- Image attachments (sheet music photos, event flyers, general images)

### Features

- Pinned announcements – Director or authorized member can pin any message to the top of the chat

- Targeted voice part messages – Director can send a message visible only to Sopranos, Altos, Tenors, or Basses (Pro tier)

- WhatsApp cross-post button – 'Share to WhatsApp' on any message opens the native OS share sheet via share_plus, allowing the director to cross-post to existing WhatsApp groups without abandoning them

- Real-time delivery via Firestore StreamProvider

- Push notification on new message via Firebase Cloud Messaging

## 5.9 Choir Dashboard Metrics

A simplified metrics dashboard is visible to all choir members, not just admins. Transparency in choir data creates passive accountability without requiring confrontation.

| **Metric** | **Visible to** | **Notes** |
| --- | --- | --- |
| Total active members | Everyone |  |
| Voice part distribution (S/A/T/B count) | Everyone | Helps directors spot weak sections before rehearsal |
| Upcoming rehearsal date/time/location | Everyone |  |
| Last rehearsal attendance % | Everyone | Social accountability without naming individuals |
| Total songs in library | Everyone |  |
| My personal attendance rate | Self only | Visible only to the individual member |
| Per-member listen tracking (Pro) | Leader + Director | Who practiced which part, how many times, last listened |
| Full attendance analytics (Pro) | Leader + Director | Trends over time, most/least consistent members, voice part breakdown |

# 6. Technical Architecture

## 6.1 Technology Stack

| **Layer** | **Technology** | **Rationale** |
| --- | --- | --- |
| Mobile app | Flutter (Dart) – Native | Single codebase for Android + iOS. Compiled to native ARM – no WebView overhead. Material 3 UI. |
| Web dashboard | Next.js 14 App Router | Reuses BlssdVybz stack. Server Actions + REST endpoints for web-only operations. |
| State management | Riverpod 2.0 | StreamProvider mirrors Firestore in real-time. Auto-dispose prevents memory leaks. |
| Navigation | go_router | Deep link support for guest director invites, choir join codes, and program links. |
| Database | Cloud Firestore | Real-time listeners. Offline persistence. Security Rules enforce per-choir role isolation. |
| Authentication | Firebase Auth | Phone OTP (primary), email, Google Sign-In. FlutterFire handles JWT auto-refresh. |
| Audio storage | Cloudflare R2 | Zero egress fees vs Firebase Storage. Global CDN. Presigned URLs for time-limited access. |
| Media storage | Firebase Storage | Profile photos, choir covers, score PDFs, chat images/voice notes. |
| Push notifications | Firebase Cloud Messaging | Background + foreground handling. flutter_local_notifications for display. Topic-based voice part targeting. |
| Background jobs | Cloud Functions v2 | Payment webhooks, rehearsal reminders, guest token expiry, freemium enforcement, listen analytics. |
| Payments | MTN MoMo + Airtel Money | Collections API via Cloud Functions. HMAC webhook verification. UGX currency. |
| Local cache | Hive + SharedPreferences | Offline audio metadata. User settings. App works between syncs. |
| CI/CD | GitHub Actions | Flutter build, test, APK/AAB auto-build. Firebase App Distribution for beta. |
| Hosting | Firebase App Hosting | Global CDN for Next.js web dashboard. Auto SSL. Zero-downtime deploys. |

## 6.2 Data Model

KwayaPro uses 13 Firestore collections. All collections are indexed by choirId for multi-choir isolation and per-choir security rule enforcement.

| **Collection** | **Key fields** |
| --- | --- |
| User | userId · name · phone · email · profilePhoto · fcmToken · createdAt |
| Choir | choirId · name · churchName · leaderId · coverPhoto · plan: free│pro · songCount · createdAt |
| ChoirMembership | choirId · userId · role: leader│director│chorister · defaultVoicePart: S│A│T│B · permissions: string[] · joinedAt |
| Song | songId · choirId · title · category · key · language · uploadedBy · createdAt |
| SongSection | sectionId · songId · title (Verse│Chorus│Bridge) · order · status: ready│coming_soon |
| AudioPart | audioPartId · sectionId · voicePart: S│A│T│B · audioUrl (R2) · duration · uploadedBy |
| ScoreAttachment | scoreId · songId · type: pdf│image · fileUrl (Firebase Storage) · label · uploadedBy |
| SongProgram | programId · choirId · eventName · eventType: mass│wedding│concert│rehearsal · eventDate · songIds[] · createdBy · publishedAt |
| RehearsalSession | sessionId · choirId · programId? · date · time · location · directorId · isGuestDirector · notes |
| Attendance | sessionId · userId · rsvp: coming│not│pending · attended: bool · voicePartOverride |
| ListenEvent | userId · audioPartId · songId · sectionId · listenedAt · durationPlayed · completed: bool |
| ChatMessage | messageId · choirId · senderId · type: text│audio│image · content · targetVoicePart? · pinned: bool · timestamp |
| Subscription | choirId · plan: free│pro · provider: mtn│airtel · startDate · endDate · txRef · status |

## 6.3 Security Model

- Firestore Security Rules enforce role and permissions array per choirId – no cross-choir data access is possible at the database level

- R2 audio files are served exclusively via time-limited presigned URLs – no direct public access to the storage bucket

- Guest director tokens are stored in Firestore with an expiry timestamp and validated server-side before any privileged operation

- Payment webhooks from MTN and Airtel are verified via HMAC signature inside Cloud Functions before any subscription state is updated

- FCM tokens are stored per device in the user's Firestore document and rotated on each app session

- All sensitive environment variables (API keys, webhook secrets) are stored in Firebase Secret Manager, never hardcoded

# 7. Development Sprint Plan

The MVP is planned as a 6-week sprint. The sprint prioritizes Android delivery and the three core pain points, audio library, attendance, and choir communication, before adding the recording studio and payment features.

| **Week** | **Focus** | **Deliverables** | **Acceptance criteria** |
| --- | --- | --- | --- |
| 1 | Foundation - Auth, choir creation, member management | Phone OTP auth · Choir create/join flow · Invite code + deep link · Voice part assignment · Role assignment | User can create a choir, share a link, and a new member can join and see their voice part assigned |
| 2 | Song library - upload, structure, free tier enforcement | Song + section creation · External audio upload (file_picker) · R2 storage · 3-song free limit · Upgrade prompt | Director can upload an audio file to a song section. 4th upload triggers upgrade prompt. Chorister sees audio for their voice part. |
| 3 | In-app recording studio - virtual keyboard, recording, pitch indicator | Recording screen (landscape) · Virtual keyboard · Octave controls · Sustain button · Pitch indicator · Metronome · Click track for rests | Director can record a voice part using the virtual keyboard for pitch reference. Pitch indicator shows live feedback. Audio uploads on save. |
| 4 | Rehearsal management - scheduling, RSVP, guest director | Rehearsal creation · Director assignment · RSVP · Push notifications · Guest director one-time link · Permission expiry | Leader can schedule a rehearsal, assign or change director. Guest director link works end-to-end. Permissions auto-expire. |
| 5 | Attendance, song program planner, score library | Attendance marking · Voice part override per session · Song program creation + publish · Score PDF/image upload · Dashboard metrics | Director can mark attendance with voice part overrides. Committee member with song_program_planner permission can create and publish a program. |
| 6 | Choir chat, payments, listen tracking, polish | Choir chat (text + voice notes + images) · WhatsApp cross-post · MTN + Airtel payment · Listen event logging · Practice tracker · UI polish · APK build | Full payment flow works end-to-end. Choir chat sends and receives. WhatsApp share button works. APK installs and runs on physical device. |

## 7.1 Definition of Done – MVP

- Android APK installable from Google Play internal test track

- Full auth flow working on physical Android device in Uganda

- Choir creation, member invite, and join flow end-to-end

- Audio upload (both in-app recording and external file) → R2 → playback on chorister device

- Virtual keyboard accessible from any screen including pre-login

- Rehearsal scheduling, RSVP, and push notifications working

- Guest director invite link generates, works, and auto-expires

- Attendance marking with voice part override working

- Song program creation and publish working for permitted members

- MTN Mobile Money payment flow end-to-end (test credentials)

- Airtel Money payment flow end-to-end (test credentials)

- Freemium limit enforced at 3 songs – upgrade prompt appears on 4th attempt

- Choir chat sending and receiving text, voice notes, and images

- WhatsApp cross-post working via native share sheet

- Beta deployed to Peter's 30 choirs for real-world validation

# 8. Critical User Flows

## 8.1 New Choir Setup

**Actor: **Choir Leader

- Install KwayaPro APK → Sign up with phone number (OTP)

- Create choir → Enter name, church/parish name, upload cover photo

- App generates invite code and shareable deep link

- Leader shares invite link via WhatsApp (share_plus native share sheet)

- Choristers tap link → install app (if needed) → sign up → auto-join choir → select voice part

- Leader optionally grants granular permissions to committee members (song_program_planner, score_librarian, etc.)

- Leader uploads first 3 songs (free tier) – each with sections and SATB audio parts

- Choristers open Songs tab → see full library filtered to their voice part → start practicing immediately

## 8.2 New Member Joining a Choir (Late Joiner)

**Actor: **Chorister

- Receives invite link from Choir Leader via WhatsApp

- Taps link → App Store / Play Store install prompt (if not installed) → installs and opens

- Signs up with phone number → OTP verified → account created

- Deep link handler auto-joins the chorister to the choir

- Chorister selects voice part (e.g. Alto)

- Immediately sees full song library – every section ever uploaded by the choir

- Taps Verse of Song 3 → hears Alto part only → begins practicing independently

- Director can see via listen tracking: 'New member listened to Alto Verse × 3 today'

- Receives push notification for next scheduled rehearsal → RSVPs

## 8.3 Last-Minute Director Replacement

**Actor: **Choir Leader + Guest Director

- Scheduled director is unavailable → Leader opens the rehearsal in the app

- Taps 'Change Director' → 'Invite via link'

- Cloud Function generates a one-time, time-limited token and deep link

- Leader shares link to available director via WhatsApp

- Director taps link → signs in (or creates account) → auto-joins rehearsal as guest director

- Firestore writes temporary director permissions scoped exclusively to this sessionId

- Guest director accesses: full member list, voice parts, complete audio library, attendance marking, audio upload

- Rehearsal ends → Cloud Function scheduled trigger fires → all guest permissions revoked automatically

## 8.4 Recording a Voice Part (In-App)

**Actor: **Director

- Director opens Songs tab → selects a song → selects section (e.g. Chorus) → taps 'Record Alto'

- Recording screen opens – device auto-locks to landscape orientation

- Director selects song key (e.g. Bb major) → app automatically plays the Alto starting note

- Director uses virtual keyboard to find and sustain any accidental notes in the harmony before recording

- Director taps Record → sings the Alto part → live pitch indicator shows green/red feedback in real time

- Director taps Stop → reviews playback → saves

- Audio uploads to Cloudflare R2 → section status updates to Ready

- Push notification sent to all Alto choristers: 'New Chorus audio uploaded for [Song Name] –  Alto part'

## 8.5 Freemium → Pro Upgrade

**Actor: **Choir Leader

- Leader attempts to upload a 4th song to the choir library

- Cloud Function checks choir's songCount – limit reached

- Flutter displays upgrade bottom sheet: 'You have used 3 of your 3 free songs. Upgrade to KwayaPro to unlock unlimited songs.'

- Leader sees pricing (Pro plan in UGX) and selects payment method: MTN Mobile Money or Airtel Money

- Leader enters their phone number → Cloud Function calls MTN MoMo Collections API

- MoMo payment prompt appears on leader's phone → leader approves the payment

- MTN sends webhook callback to Cloud Function → HMAC signature verified → transaction confirmed

- Firestore updates choir plan to 'pro' → Riverpod StreamProvider refreshes UI instantly

- Leader continues uploading, no app restart required

# 9. Non-Functional Requirements

## 9.1 Performance

- Audio playback must begin within 2 seconds of tapping a song on a standard 4G connection in Uganda

- App must be fully functional offline for core features: audio playback (cached), choir chat read (cached), attendance marking (queued writes)

- Push notifications must deliver within 30 seconds of the triggering event under normal network conditions

- Audio upload must show real-time progress feedback – no silent loading states

- App cold start time must not exceed 3 seconds on a mid-range Android device (2GB RAM)

## 9.2 Reliability

- Firestore offline persistence must be enabled, app must not break when the user loses connectivity mid-session

- Failed audio uploads must retry automatically and notify the user if they fail permanently

- Guest director token expiry must be handled server-side (Cloud Function), not client-side, to prevent bypass

- Payment state must be set exclusively by webhook confirmation from MTN/Airtel, never by client-side assertion

## 9.3 Usability

- The app must be navigable by a non-technical user (a chorister who has never used a choir app) without any onboarding tutorial, UI must be self-explanatory

- The virtual keyboard must be accessible from every screen in the app including before login, with a single tap

- All critical actions (RSVP, attendance, song playback) must be reachable within 2 taps from the home screen

- Error messages must be written in plain English, no technical error codes visible to end users

## 9.4 Localisation

- Primary language: English

- All currency displayed in UGX (Ugandan Shilling)

- Date and time displayed in EAT (East Africa Time, UTC+3)

- No assumptions about music literacy in UI labels, use plain language (e.g. 'Soprano part' not 'Soprano voice line')

## 9.5 Device Support

- Minimum Android version: Android 8.0 (API level 26), covers >95% of Android devices in Uganda

- Minimum RAM: 2GB, standard for mid-range devices in the target market

- Screen size: Optimised for 5.5–6.5 inch displays. Keyboard screen always landscape-locked.

- Storage: App size must not exceed 50MB on install. Audio cached locally only on demand.

# 10. Open Questions & Assumptions

## 10.1 Validated Assumptions

- Choir leaders in Uganda have Android smartphones – confirmed by all 6 research respondents.

- MTN Mobile Money is the primary payment method – confirmed by market context. Airtel Money is the secondary fallback.

- WhatsApp is the dominant communication channel – confirmed universally. KwayaPro will complement, not replace, WhatsApp.

- The majority of choristers cannot read music – confirmed by Peter's direct experience as a choir director and supported by respondent data.

- Choirs are willing to pay for tools that save the director time – validated by respondent descriptions of current manual effort.

## 10.2 Open Questions (Require Validation Post-Beta)

- What is the optimal Pro tier price point in UGX? Current hypothesis: UGX 40,000–60,000/month. To be validated with beta choirs before public launch.

- Will choristers actively download and use the app, or will adoption friction remain at the choir leader level? Beta will provide direct signal on this.

- Do choir leaders prefer monthly or annual subscription billing? Annual at a discount may suit church budget cycles better.

- Is there demand for a Director's solo account (not tied to a specific choir) that a freelance director could use to manage their network across multiple choirs?

- Choir finances (member contributions, expenses) were cited as a pain point by 2 respondents. Is this a Phase 2 feature or a separate product opportunity?

- Will the recording quality of the virtual keyboard + in-app recording path be acceptable to experienced directors who are accustomed to recording on dedicated equipment?

## 10.3 Risks

| **Risk** | **Likelihood** | **Mitigation** |
| --- | --- | --- |
| Chorister adoption – leaders upgrade but members don't install the app | Medium | WhatsApp invite flow makes install as frictionless as possible. Core chorister value (audio parts) is immediately available on first open. |
| MTN/Airtel API integration delays or sandbox access issues | Medium | Begin payment integration in Week 5 buffer. Use manual payment confirmation as temporary fallback during beta. |
| Recording quality insufficient for ear-trained choristers to learn from | Low | External upload path allows directors with existing recording setups to bypass in-app recording entirely. |
| Solo developer bandwidth – BlssdVybz Sprint 4 running concurrently | High | KwayaPro reuses identical tech stack as BlssdVybz. No context switching cost. Sprint plan is deliberately lean. |
| Network reliability – inconsistent 4G in some areas of Uganda | Medium | Firestore offline persistence + local audio caching ensure core functionality works between syncs. |

# 11. Appendix

## 11.1 Flutter Package Dependencies

| **Package** | **Version** | **Purpose** |
| --- | --- | --- |
| flutter_riverpod | ^2.5.1 | State management |
| go_router | ^13.2.0 | Navigation + deep links |
| firebase_core | ^2.27.0 | FlutterFire bootstrap |
| firebase_auth | ^4.17.4 | Auth — OTP + email |
| cloud_firestore | ^4.15.5 | Real-time database |
| firebase_storage | ^11.6.5 | Media uploads |
| firebase_messaging | ^14.7.19 | Push notifications |
| just_audio | ^0.9.36 | Voice part playback |
| audio_session | ^0.1.18 | Audio focus management |
| record | ^5.0.4 | In-app voice recording |
| file_picker | ^8.0.0 | External file upload |
| hive_flutter | ^1.1.0 | Offline cache |
| http | ^1.2.1 | R2 presigned uploads |
| share_plus | ^7.2.2 | WhatsApp share sheet |
| image_picker | ^1.0.7 | Photo uploads |
| flutter_local_notifications | ^17.0.0 | FCM display |
| permission_handler | ^11.3.0 | Mic + storage permissions |
| connectivity_plus | ^6.0.1 | Offline detection |

## 11.2 Firestore Security Rules – Pseudocode

The following pseudocode describes the intended security rule logic. Actual implementation will be in Firestore Security Rules syntax.

- A user may read a choir's data only if they have an active ChoirMembership document for that choirId.

- A user may write to a song or section only if their ChoirMembership role is 'leader' or 'director', OR their permissions array includes 'audio_uploader'.

- A user may write to a SongProgram only if their role is 'leader' or 'director', OR their permissions array includes 'song_program_planner'.

- A user may write to Attendance only if their role is 'leader' or 'director', OR their permissions array includes 'attendance_manager'.

- A user may write to ChoirMembership only if their role is 'leader' for that choirId – no other role can modify membership.

- A user may read their own ListenEvent records. A leader or director may read all ListenEvent records for their choirId.

- Subscription documents may only be written by Cloud Functions using the Firebase Admin SDK – never by client-side code.

## 11.3 Glossary

| **Term** | **Definition** |
| --- | --- |
| SATB | Soprano, Alto, Tenor, Bass – the four standard choral voice parts |
| Voice part | The specific harmonic line assigned to a subset of choir members (S, A, T, or B) |
| Choir Leader | The administrative owner of a choir in KwayaPro – manages members, billing, and permissions. Not necessarily the musical director. |
| Director | The musical lead of a rehearsal session. Session-based, not permanent. Can be a guest invited via one-time link. |
| Guest director | A director invited to a single rehearsal via a one-time link. Permissions are scoped to that sessionId and auto-expire. |
| Song section | A discrete part of a song (Verse, Chorus, Bridge, etc.) that can be recorded and uploaded independently. |
| Freemium | The free tier of KwayaPro – fully functional for up to 3 songs per choir. Upgrade prompt appears on 4th song. |
| R2 | Cloudflare R2 – the cloud object storage used for all voice part audio files. |
| FCM | Firebase Cloud Messaging – the push notification infrastructure. |
| MoMo | MTN Mobile Money – Uganda's dominant mobile payment platform. |
| Listen tracking | The logging of every audio play event (ListenEvent) for practice accountability analytics – Pro tier only. |

	KwayaPro — Built for African Church Choirs — Uganda → East Africa	Page 1