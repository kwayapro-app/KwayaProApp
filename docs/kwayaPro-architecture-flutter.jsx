import { useState } from "react";

const colors = {
  bg: "#0A0E1A",
  surface: "#111827",
  surfaceLight: "#1C2535",
  border: "#1E2D45",
  gold: "#F5A623",
  goldLight: "#FFD08A",
  blue: "#3B82F6",
  blueLight: "#93C5FD",
  green: "#10B981",
  greenLight: "#6EE7B7",
  purple: "#8B5CF6",
  purpleLight: "#C4B5FD",
  red: "#EF4444",
  redLight: "#FCA5A5",
  cyan: "#06B6D4",
  cyanLight: "#A5F3FC",
  orange: "#F97316",
  teal: "#14B8A6",
  text: "#E2E8F0",
  textMuted: "#64748B",
  textDim: "#94A3B8",
};

const layers = [
  {
    id: "client",
    label: "CLIENT LAYER",
    color: colors.gold,
    nodes: [
      {
        id: "android",
        label: "Android App",
        sub: "Flutter (Dart) — Native",
        icon: "📱",
        color: colors.gold,
        badge: "NATIVE",
        detail: [
          "100% native Android UI (Material 3)",
          "Flutter SDK — Dart language",
          "FlutterFire for all Firebase services",
          "just_audio for voice part playback",
          "flutter_local_notifications for FCM",
          "go_router for navigation",
          "Riverpod for state management",
          "Google Play Store distribution",
        ],
      },
      {
        id: "ios",
        label: "iOS App",
        sub: "Flutter (Dart) — Native",
        icon: "🍎",
        color: colors.gold,
        badge: "PHASE 2",
        detail: [
          "100% native iOS UI (Cupertino widgets)",
          "Same Flutter codebase as Android",
          "Shared business logic — zero duplication",
          "Apple Push Notification Service via FCM",
          "App Store distribution",
          "iOS-specific audio session handling",
          "Adaptive UI for iPad support",
        ],
      },
      {
        id: "web",
        label: "Web Dashboard",
        sub: "Next.js 14 App Router",
        icon: "🖥️",
        color: colors.gold,
        badge: "ADMIN",
        detail: [
          "Choir admin panel for leaders",
          "Bulk audio uploads (easier on desktop)",
          "Analytics & attendance reports",
          "Member & director management",
          "Firebase Admin SDK via API routes",
          "Tailwind CSS + shadcn/ui",
          "Firebase App Hosting deployment",
        ],
      },
    ],
  },
  {
    id: "flutter",
    label: "FLUTTER ARCHITECTURE LAYER",
    color: colors.teal,
    nodes: [
      {
        id: "state",
        label: "State Management",
        sub: "Riverpod 2.0",
        icon: "🔄",
        color: colors.teal,
        detail: [
          "AsyncNotifierProvider for async state",
          "StreamProvider for real-time Firestore",
          "StateProvider for UI-local state",
          "Repository pattern for data access",
          "Offline-first with Firestore cache",
          "Auto-dispose for memory efficiency",
        ],
      },
      {
        id: "navigation",
        label: "Navigation & Routing",
        sub: "go_router",
        icon: "🗺️",
        color: colors.teal,
        detail: [
          "Declarative routing with go_router",
          "Deep link support for invite codes",
          "Auth-gated route guards",
          "Role-based screen access",
          "Bottom nav + nested navigation",
          "Rehearsal invite deep links",
        ],
      },
      {
        id: "local",
        label: "Local Storage",
        sub: "Hive + Shared Preferences",
        icon: "💾",
        color: colors.teal,
        detail: [
          "Hive for offline audio metadata cache",
          "Shared Preferences for user settings",
          "Firestore offline persistence enabled",
          "Audio file local caching (path_provider)",
          "Works fully offline between syncs",
        ],
      },
    ],
  },
  {
    id: "api",
    label: "APPLICATION LAYER",
    color: colors.blue,
    nodes: [
      {
        id: "nextapi",
        label: "Next.js API Routes",
        sub: "Web Dashboard Backend",
        icon: "⚡",
        color: colors.blue,
        detail: [
          "REST endpoints for web dashboard only",
          "Firebase Admin SDK (server-side)",
          "Input validation with Zod",
          "Bulk audio upload orchestration",
          "Webhook receiver for payments",
          "Rate limiting middleware",
        ],
      },
      {
        id: "hosting",
        label: "Firebase App Hosting",
        sub: "Web Dashboard CDN",
        icon: "🌐",
        color: colors.blue,
        detail: [
          "Hosts Next.js web dashboard only",
          "Global CDN for dashboard assets",
          "Auto SSL certificates",
          "GitHub CI/CD pipeline",
          "Flutter APK built via GitHub Actions",
          "Zero-downtime deployments",
        ],
      },
      {
        id: "auth",
        label: "Firebase Auth",
        sub: "Identity — FlutterFire",
        icon: "🔐",
        color: colors.blue,
        detail: [
          "firebase_auth Flutter package",
          "Phone number OTP (primary — Uganda)",
          "Email + password fallback",
          "Google Sign-In option",
          "Auth state stream → Riverpod provider",
          "JWT auto-refresh handled by FlutterFire",
        ],
      },
    ],
  },
  {
    id: "core",
    label: "CORE SERVICES LAYER",
    color: colors.purple,
    nodes: [
      {
        id: "firestore",
        label: "Cloud Firestore",
        sub: "cloud_firestore Flutter pkg",
        icon: "🗄️",
        color: colors.purple,
        detail: [
          "Real-time listeners via StreamProvider",
          "Offline persistence enabled",
          "Security Rules enforce role-per-choir",
          "Composite indexes for choir queries",
          "Batch writes for attendance marking",
          "Transactions for subscription state",
        ],
      },
      {
        id: "fcm",
        label: "Firebase Cloud Messaging",
        sub: "firebase_messaging Flutter pkg",
        icon: "🔔",
        color: colors.purple,
        detail: [
          "Background + foreground message handling",
          "flutter_local_notifications for display",
          "Rehearsal reminders (scheduled via Functions)",
          "New audio upload alerts",
          "Director invite push alerts",
          "Voice-part targeted topic messaging",
        ],
      },
      {
        id: "functions",
        label: "Cloud Functions v2",
        sub: "Background Processing",
        icon: "⚙️",
        color: colors.purple,
        detail: [
          "Payment webhook handler (MTN + Airtel)",
          "R2 audio upload post-processing",
          "Scheduled rehearsal reminder dispatch",
          "Freemium song limit enforcement",
          "Subscription state management",
          "Attendance analytics aggregation",
        ],
      },
    ],
  },
  {
    id: "storage",
    label: "STORAGE LAYER",
    color: colors.green,
    nodes: [
      {
        id: "r2",
        label: "Cloudflare R2",
        sub: "Voice Part Audio Files",
        icon: "🎵",
        color: colors.green,
        detail: [
          "Direct upload via presigned URLs",
          "Flutter: http package for upload",
          "just_audio plays directly from R2 URL",
          "Per-choir folder namespacing",
          "Zero egress fees (vs Firebase Storage)",
          "Global CDN for fast audio delivery",
        ],
      },
      {
        id: "fbstorage",
        label: "Firebase Storage",
        sub: "firebase_storage Flutter pkg",
        icon: "🖼️",
        color: colors.green,
        detail: [
          "Profile photos + choir cover images",
          "Chat image & voice note attachments",
          "Sheet music photo uploads",
          "Event flyers",
          "Upload progress streams in Flutter",
        ],
      },
    ],
  },
  {
    id: "payment",
    label: "PAYMENT LAYER",
    color: colors.orange,
    nodes: [
      {
        id: "mtn",
        label: "MTN Mobile Money",
        sub: "MTN MoMo API",
        icon: "📲",
        color: colors.orange,
        detail: [
          "Collections API — request to pay",
          "Flutter: http call to Cloud Function",
          "Cloud Function initiates MoMo request",
          "Webhook confirms payment to Firestore",
          "Subscription unlocked in real-time",
          "UGX currency — Uganda primary",
        ],
      },
      {
        id: "airtel",
        label: "Airtel Money",
        sub: "Airtel Africa API",
        icon: "📡",
        color: colors.orange,
        detail: [
          "Airtel Money Collections API",
          "Same Cloud Function payment flow",
          "Fallback when MTN unavailable",
          "Transaction callbacks to Firestore",
          "UGX currency support",
        ],
      },
      {
        id: "billing",
        label: "Billing Engine",
        sub: "Firestore + Cloud Functions",
        icon: "💳",
        color: colors.orange,
        detail: [
          "Free tier: 3 songs per choir",
          "Firestore songCount field enforced",
          "Flutter shows upgrade prompt at limit",
          "Pro unlock written to Firestore instantly",
          "Subscription history log collection",
          "Auto-expiry check on app launch",
        ],
      },
    ],
  },
  {
    id: "external",
    label: "EXTERNAL INTEGRATIONS",
    color: colors.cyan,
    nodes: [
      {
        id: "whatsapp",
        label: "WhatsApp Share",
        sub: "share_plus Flutter package",
        icon: "💬",
        color: colors.cyan,
        detail: [
          "share_plus triggers native share sheet",
          "Share rehearsal announcements",
          "Share choir invite codes/links",
          "Cross-post choir chat announcements",
          "No API key needed — OS-level share",
        ],
      },
      {
        id: "cicd",
        label: "CI/CD Pipeline",
        sub: "GitHub Actions",
        icon: "🚀",
        color: colors.cyan,
        detail: [
          "Flutter build on every push",
          "flutter test — unit + widget tests",
          "Android APK + AAB auto-build",
          "iOS IPA build (phase 2)",
          "Firebase App Distribution for beta",
          "Google Play internal track auto-upload",
        ],
      },
    ],
  },
];

const flutterPackages = [
  { name: "firebase_core", purpose: "FlutterFire bootstrap", category: "Firebase" },
  { name: "firebase_auth", purpose: "Auth — OTP + email", category: "Firebase" },
  { name: "cloud_firestore", purpose: "Real-time database", category: "Firebase" },
  { name: "firebase_storage", purpose: "Media uploads", category: "Firebase" },
  { name: "firebase_messaging", purpose: "Push notifications", category: "Firebase" },
  { name: "flutter_riverpod", purpose: "State management", category: "State" },
  { name: "riverpod_annotation", purpose: "Code generation", category: "State" },
  { name: "go_router", purpose: "Navigation + deep links", category: "Navigation" },
  { name: "just_audio", purpose: "Voice part playback", category: "Audio" },
  { name: "audio_session", purpose: "Audio focus mgmt", category: "Audio" },
  { name: "record", purpose: "Voice note recording", category: "Audio" },
  { name: "hive_flutter", purpose: "Offline data cache", category: "Storage" },
  { name: "shared_preferences", purpose: "User settings", category: "Storage" },
  { name: "path_provider", purpose: "Local file paths", category: "Storage" },
  { name: "http", purpose: "R2 presigned uploads", category: "Network" },
  { name: "dio", purpose: "API calls + interceptors", category: "Network" },
  { name: "share_plus", purpose: "WhatsApp share sheet", category: "Integration" },
  { name: "image_picker", purpose: "Photo uploads", category: "Integration" },
  { name: "flutter_local_notifications", purpose: "FCM display", category: "Notifications" },
  { name: "permission_handler", purpose: "Mic + storage perms", category: "System" },
  { name: "connectivity_plus", purpose: "Offline detection", category: "System" },
  { name: "intl", purpose: "Date + currency format", category: "Utilities" },
];

const categoryColors = {
  Firebase: colors.gold,
  State: colors.purple,
  Navigation: colors.teal,
  Audio: colors.green,
  Storage: colors.blue,
  Network: colors.cyan,
  Integration: colors.orange,
  Notifications: colors.red,
  System: colors.textDim,
  Utilities: colors.textMuted,
};

const dataModels = [
  { name: "User", color: colors.gold, fields: ["userId", "name", "phone", "email", "profilePhoto", "fcmToken", "createdAt"] },
  { name: "Choir", color: colors.blue, fields: ["choirId", "name", "churchName", "leaderId", "coverPhoto", "plan: free|pro", "songCount", "createdAt"] },
  { name: "ChoirMembership", color: colors.purple, fields: ["choirId", "userId", "role: leader|director|chorister", "defaultVoicePart: S|A|T|B", "joinedAt"] },
  { name: "Song", color: colors.green, fields: ["songId", "choirId", "title", "category", "uploadedBy", "createdAt"] },
  { name: "AudioPart", color: colors.green, fields: ["audioPartId", "songId", "voicePart: S|A|T|B", "audioUrl (R2)", "duration", "uploadedBy"] },
  { name: "RehearsalSession", color: colors.orange, fields: ["sessionId", "choirId", "date", "time", "location", "directorId", "isGuestDirector", "notes"] },
  { name: "Attendance", color: colors.orange, fields: ["sessionId", "userId", "rsvp: coming|not|pending", "attended: bool", "voicePartOverride"] },
  { name: "ChatMessage", color: colors.cyan, fields: ["messageId", "choirId", "senderId", "type: text|audio|image", "content", "targetVoicePart?", "pinned: bool", "timestamp"] },
  { name: "Subscription", color: colors.red, fields: ["choirId", "plan: free|pro", "provider: mtn|airtel", "startDate", "endDate", "txRef", "status"] },
];

const tabs = [
  { id: "architecture", label: "System Architecture" },
  { id: "flutter", label: "Flutter Stack" },
  { id: "datamodel", label: "Data Model" },
  { id: "flows", label: "Key User Flows" },
];

const flows = [
  {
    title: "New choir setup",
    actor: "Choir Leader",
    color: colors.gold,
    icon: "👑",
    steps: [
      "Install KwayaPro APK → Sign up via phone OTP (firebase_auth)",
      "Create choir → Enter name, church → Upload cover photo (Firebase Storage)",
      "Share invite code via WhatsApp (share_plus → native share sheet)",
      "Choristers install app → Enter code → Select voice part → Appear in Firestore",
      "Leader uploads first 3 songs (free tier) with SATB audio to Cloudflare R2",
      "Choristers open app → StreamProvider loads their voice part audio instantly",
    ],
  },
  {
    title: "Voice part audio playback",
    actor: "Chorister",
    color: colors.green,
    icon: "🎵",
    steps: [
      "Chorister opens Songs tab → StreamProvider streams choir song library",
      "Firestore query filters songs by choirId, returns AudioPart for their voice",
      "Taps song → just_audio loads presigned R2 URL → native audio playback",
      "audio_session handles audio focus (pauses if call comes in)",
      "Can loop, replay, adjust speed — all native Flutter audio controls",
      "New member joins late → full library already in Firestore → immediate access",
    ],
  },
  {
    title: "Last-minute director replacement",
    actor: "Choir Leader + Guest Director",
    color: colors.blue,
    icon: "🎼",
    steps: [
      "Leader opens rehearsal → taps 'Change Director' → 'Invite via link'",
      "Cloud Function generates one-time token → deep link created",
      "share_plus sends link to director via WhatsApp",
      "Director taps link → go_router deep link handler → auto-joins rehearsal",
      "Firestore writes temp director permission scoped to sessionId",
      "Director gets full access: member list, audio library, attendance marking",
      "Rehearsal ends → Cloud Function scheduled trigger expires guest permission",
    ],
  },
  {
    title: "Freemium → Pro upgrade",
    actor: "Choir Leader",
    color: colors.orange,
    icon: "💳",
    steps: [
      "Leader attempts 4th song upload → Cloud Function checks songCount ≥ 3",
      "Flutter shows upgrade bottom sheet: KSh/UGX pricing, MTN or Airtel",
      "Leader selects MTN → enters phone → Cloud Function calls MoMo Collections API",
      "MoMo prompt appears on leader's phone → approves payment",
      "MTN webhook hits Cloud Function → verifies HMAC signature",
      "Firestore updates choir plan to 'pro' → Riverpod StreamProvider refreshes UI",
      "Leader continues uploading — no app restart needed",
    ],
  },
  {
    title: "Rehearsal RSVP + attendance",
    actor: "Director + Choristers",
    color: colors.purple,
    icon: "📋",
    steps: [
      "Director schedules rehearsal → Firestore write → Cloud Function triggers FCM",
      "All choir members receive push notification (firebase_messaging)",
      "Choristers open app → tap RSVP → Firestore updates attendance doc",
      "Director opens attendance screen on rehearsal day → sees RSVP list",
      "Director taps each member present → Firestore batch write for all attendance",
      "Choir dashboard metrics update in real-time via StreamProvider",
    ],
  },
  {
    title: "Choir chat + WhatsApp cross-post",
    actor: "Director / Leader",
    color: colors.cyan,
    icon: "💬",
    steps: [
      "Director opens Choir Chat → real-time Firestore stream renders messages",
      "Types announcement or records voice note (record package → Firebase Storage)",
      "Optional: selects 'Sopranos only' → message tagged with targetVoicePart",
      "Taps send → Firestore write → Cloud Function sends FCM to relevant members",
      "Taps 'Share to WhatsApp' → share_plus opens native share sheet",
      "Message pinned at top → all members see it on next app open",
    ],
  },
];

export default function KwayaProArchitectureFlutter() {
  const [activeNode, setActiveNode] = useState(null);
  const [activeTab, setActiveTab] = useState("architecture");
  const [filterCategory, setFilterCategory] = useState("All");

  const categories = ["All", ...Array.from(new Set(flutterPackages.map(p => p.category)))];
  const filtered = filterCategory === "All" ? flutterPackages : flutterPackages.filter(p => p.category === filterCategory);

  return (
    <div style={{ fontFamily: "'Georgia', serif", background: colors.bg, minHeight: "100vh", color: colors.text }}>
      {/* Header */}
      <div style={{ background: `linear-gradient(135deg, #0A0E1A 0%, #111827 50%, #0A1628 100%)`, borderBottom: `1px solid ${colors.border}`, padding: "32px 40px 24px", position: "relative", overflow: "hidden" }}>
        <div style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0, background: `radial-gradient(ellipse at 20% 50%, rgba(245,166,35,0.06) 0%, transparent 60%), radial-gradient(ellipse at 80% 20%, rgba(20,184,166,0.06) 0%, transparent 60%)` }} />
        <div style={{ position: "relative" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "16px", marginBottom: "8px" }}>
            <div style={{ width: "48px", height: "48px", background: `linear-gradient(135deg, ${colors.gold}, ${colors.orange})`, borderRadius: "12px", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "24px", boxShadow: `0 0 24px rgba(245,166,35,0.3)` }}>🎵</div>
            <div>
              <div style={{ fontSize: "28px", fontWeight: "700", letterSpacing: "3px", background: `linear-gradient(135deg, ${colors.goldLight}, ${colors.gold})`, WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>KWAYAPRO</div>
              <div style={{ fontSize: "11px", letterSpacing: "4px", color: colors.textMuted, fontFamily: "monospace" }}>FLUTTER NATIVE ARCHITECTURE — MVP v2.0</div>
            </div>
          </div>
          <div style={{ display: "flex", gap: "12px", marginTop: "16px", flexWrap: "wrap" }}>
            {[
              { label: "Mobile", value: "Flutter (Dart) — Native" },
              { label: "Web", value: "Next.js 14 App Router" },
              { label: "Backend", value: "Firebase + Cloudflare R2" },
              { label: "Platforms", value: "Android → iOS → Web" },
              { label: "Payment", value: "MTN + Airtel MoMo" },
            ].map(item => (
              <div key={item.label} style={{ background: "rgba(255,255,255,0.03)", border: `1px solid ${colors.border}`, borderRadius: "8px", padding: "8px 14px" }}>
                <div style={{ fontSize: "10px", color: colors.textMuted, letterSpacing: "2px", fontFamily: "monospace" }}>{item.label}</div>
                <div style={{ fontSize: "12px", color: colors.text, marginTop: "2px" }}>{item.value}</div>
              </div>
            ))}
            <div style={{ background: `${colors.teal}22`, border: `1px solid ${colors.teal}44`, borderRadius: "8px", padding: "8px 14px" }}>
              <div style={{ fontSize: "10px", color: colors.teal, letterSpacing: "2px", fontFamily: "monospace" }}>CHANGE FROM v1</div>
              <div style={{ fontSize: "12px", color: colors.teal, marginTop: "2px" }}>Capacitor → Flutter Native</div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: "flex", borderBottom: `1px solid ${colors.border}`, background: colors.surface, padding: "0 40px" }}>
        {tabs.map(tab => (
          <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{ padding: "14px 20px", background: "none", border: "none", borderBottom: activeTab === tab.id ? `2px solid ${colors.gold}` : "2px solid transparent", color: activeTab === tab.id ? colors.gold : colors.textMuted, cursor: "pointer", fontSize: "12px", letterSpacing: "1px", fontFamily: "monospace", fontWeight: activeTab === tab.id ? "600" : "400", transition: "all 0.2s" }}>{tab.label.toUpperCase()}</button>
        ))}
      </div>

      <div style={{ padding: "32px 40px" }}>

        {/* ARCHITECTURE TAB */}
        {activeTab === "architecture" && (
          <div>
            <p style={{ color: colors.textDim, fontSize: "13px", fontFamily: "monospace", letterSpacing: "1px", marginBottom: "24px" }}>Click any node to expand. Flutter apps communicate directly with Firebase — no intermediate API layer needed for mobile.</p>
            {layers.map((layer, li) => (
              <div key={layer.id} style={{ marginBottom: "24px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "12px" }}>
                  <div style={{ width: "4px", height: "20px", background: layer.color, borderRadius: "2px", boxShadow: `0 0 8px ${layer.color}` }} />
                  <span style={{ fontSize: "10px", letterSpacing: "3px", color: layer.color, fontFamily: "monospace", fontWeight: "700" }}>{layer.label}</span>
                  <div style={{ flex: 1, height: "1px", background: `linear-gradient(90deg, ${layer.color}33, transparent)` }} />
                </div>
                <div style={{ display: "grid", gridTemplateColumns: `repeat(${layer.nodes.length}, 1fr)`, gap: "12px" }}>
                  {layer.nodes.map(node => (
                    <div key={node.id} onClick={() => setActiveNode(activeNode?.id === node.id ? null : node)} style={{ background: activeNode?.id === node.id ? `linear-gradient(135deg, ${node.color}22, ${node.color}11)` : colors.surfaceLight, border: `1px solid ${activeNode?.id === node.id ? node.color : colors.border}`, borderRadius: "12px", padding: "16px", cursor: "pointer", transition: "all 0.25s", boxShadow: activeNode?.id === node.id ? `0 0 20px ${node.color}33` : "none" }}>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: "10px" }}>
                        <div style={{ width: "36px", height: "36px", flexShrink: 0, background: `${node.color}22`, border: `1px solid ${node.color}44`, borderRadius: "8px", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "18px" }}>{node.icon}</div>
                        <div style={{ flex: 1 }}>
                          <div style={{ display: "flex", alignItems: "center", gap: "6px", flexWrap: "wrap" }}>
                            <div style={{ fontWeight: "700", fontSize: "14px", color: colors.text }}>{node.label}</div>
                            {node.badge && <span style={{ fontSize: "9px", padding: "2px 6px", background: `${node.color}33`, color: node.color, borderRadius: "4px", fontFamily: "monospace", letterSpacing: "1px" }}>{node.badge}</span>}
                          </div>
                          <div style={{ fontSize: "11px", color: node.color, marginTop: "2px", fontFamily: "monospace" }}>{node.sub}</div>
                        </div>
                      </div>
                      {activeNode?.id === node.id && (
                        <div style={{ marginTop: "14px", paddingTop: "14px", borderTop: `1px solid ${node.color}33` }}>
                          {node.detail.map((d, i) => (
                            <div key={i} style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "6px", fontSize: "12px", color: colors.textDim, fontFamily: "monospace" }}>
                              <div style={{ width: "4px", height: "4px", borderRadius: "50%", background: node.color, flexShrink: 0 }} />
                              {d}
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
                {li < layers.length - 1 && <div style={{ textAlign: "center", margin: "8px 0 0", color: colors.textMuted, fontSize: "18px" }}>↓</div>}
              </div>
            ))}

            {/* Key difference callout */}
            <div style={{ marginTop: "24px", background: `${colors.teal}11`, border: `1px solid ${colors.teal}33`, borderRadius: "12px", padding: "16px 20px", display: "flex", gap: "16px", alignItems: "flex-start" }}>
              <span style={{ fontSize: "20px" }}>🔄</span>
              <div>
                <div style={{ fontSize: "12px", color: colors.teal, fontWeight: "700", letterSpacing: "2px", fontFamily: "monospace" }}>KEY ARCHITECTURAL DIFFERENCE FROM v1 (CAPACITOR)</div>
                <div style={{ fontSize: "12px", color: colors.textDim, marginTop: "8px", lineHeight: "1.8", fontFamily: "monospace" }}>
                  Flutter apps communicate directly with Firebase via FlutterFire SDK — no web server in the middle for mobile · just_audio delivers true native audio performance vs HTML5 Audio in Capacitor · go_router handles deep links natively (rehearsal invites, choir join codes) · Riverpod streams mirror Firestore in real-time with zero boilerplate · Compiled to native ARM code — no WebView rendering overhead · Shared Dart codebase for Android + iOS with platform-adaptive UI
                </div>
              </div>
            </div>

            <div style={{ marginTop: "16px", background: `${colors.red}11`, border: `1px solid ${colors.red}33`, borderRadius: "12px", padding: "16px 20px", display: "flex", gap: "16px", alignItems: "flex-start" }}>
              <span style={{ fontSize: "20px" }}>🔒</span>
              <div>
                <div style={{ fontSize: "12px", color: colors.red, fontWeight: "700", letterSpacing: "2px", fontFamily: "monospace" }}>SECURITY</div>
                <div style={{ fontSize: "12px", color: colors.textDim, marginTop: "8px", lineHeight: "1.8", fontFamily: "monospace" }}>
                  Firestore Security Rules enforce role-based access scoped per choirId · R2 audio served via time-limited presigned URLs only · Guest director tokens stored in Firestore with expiry timestamp · Payment webhooks verified via HMAC signature in Cloud Functions · FCM tokens rotated and stored per device in Firestore user doc
                </div>
              </div>
            </div>
          </div>
        )}

        {/* FLUTTER STACK TAB */}
        {activeTab === "flutter" && (
          <div>
            <p style={{ color: colors.textDim, fontSize: "13px", fontFamily: "monospace", marginBottom: "20px", letterSpacing: "1px" }}>
              All Flutter/Dart packages for KwayaPro. Add to pubspec.yaml. Filtered by category.
            </p>

            {/* Project structure */}
            <div style={{ background: colors.surfaceLight, border: `1px solid ${colors.border}`, borderRadius: "12px", padding: "16px 20px", marginBottom: "24px" }}>
              <div style={{ fontSize: "11px", color: colors.gold, letterSpacing: "3px", fontFamily: "monospace", marginBottom: "14px", fontWeight: "700" }}>FLUTTER PROJECT STRUCTURE</div>
              <div style={{ fontFamily: "monospace", fontSize: "12px", color: colors.textDim, lineHeight: "1.9" }}>
                {`kwayapro/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # GoRouter + ProviderScope
│   ├── core/
│   │   ├── firebase/               # FlutterFire init + config
│   │   ├── router/                 # go_router routes + guards
│   │   ├── theme/                  # Material 3 theme
│   │   └── utils/
│   ├── features/
│   │   ├── auth/                   # Login, OTP, onboarding
│   │   ├── choir/                  # Choir creation, management
│   │   ├── songs/                  # Song library, audio upload
│   │   ├── audio/                  # just_audio player
│   │   ├── rehearsal/              # Scheduling, RSVP
│   │   ├── attendance/             # Marking, history
│   │   ├── chat/                   # Real-time choir chat
│   │   ├── dashboard/              # Choir metrics
│   │   └── subscription/           # MTN / Airtel payment
│   └── shared/
│       ├── models/                 # Firestore data models
│       ├── repositories/           # Data access layer
│       ├── providers/              # Riverpod providers
│       └── widgets/                # Shared UI components
├── android/
├── ios/                            # Phase 2
├── pubspec.yaml
└── firebase.json`}
              </div>
            </div>

            {/* Category filter */}
            <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", marginBottom: "16px" }}>
              {categories.map(cat => (
                <button key={cat} onClick={() => setFilterCategory(cat)} style={{ padding: "6px 14px", borderRadius: "20px", border: `1px solid ${filterCategory === cat ? (categoryColors[cat] || colors.gold) : colors.border}`, background: filterCategory === cat ? `${(categoryColors[cat] || colors.gold)}22` : "transparent", color: filterCategory === cat ? (categoryColors[cat] || colors.gold) : colors.textMuted, cursor: "pointer", fontSize: "11px", fontFamily: "monospace", transition: "all 0.2s" }}>{cat}</button>
              ))}
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "10px" }}>
              {filtered.map(pkg => (
                <div key={pkg.name} style={{ background: colors.surfaceLight, border: `1px solid ${colors.border}`, borderRadius: "10px", padding: "12px 14px" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "4px" }}>
                    <div style={{ width: "6px", height: "6px", borderRadius: "50%", background: categoryColors[pkg.category] || colors.textMuted, flexShrink: 0 }} />
                    <span style={{ fontSize: "12px", color: colors.text, fontFamily: "monospace", fontWeight: "700" }}>{pkg.name}</span>
                  </div>
                  <div style={{ fontSize: "11px", color: colors.textMuted, marginLeft: "14px" }}>{pkg.purpose}</div>
                  <div style={{ fontSize: "10px", color: categoryColors[pkg.category] || colors.textMuted, marginLeft: "14px", marginTop: "4px", fontFamily: "monospace" }}>{pkg.category}</div>
                </div>
              ))}
            </div>

            {/* pubspec snippet */}
            <div style={{ background: colors.surfaceLight, border: `1px solid ${colors.border}`, borderRadius: "12px", padding: "16px 20px", marginTop: "24px" }}>
              <div style={{ fontSize: "11px", color: colors.gold, letterSpacing: "3px", fontFamily: "monospace", marginBottom: "14px", fontWeight: "700" }}>PUBSPEC.YAML — KEY DEPENDENCIES</div>
              <div style={{ fontFamily: "monospace", fontSize: "12px", color: colors.textDim, lineHeight: "2" }}>
                {`dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^13.2.0
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.4
  cloud_firestore: ^4.15.5
  firebase_storage: ^11.6.5
  firebase_messaging: ^14.7.19
  just_audio: ^0.9.36
  audio_session: ^0.1.18
  record: ^5.0.4
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.2
  http: ^1.2.1
  share_plus: ^7.2.2
  image_picker: ^1.0.7
  flutter_local_notifications: ^17.0.0
  permission_handler: ^11.3.0
  connectivity_plus: ^6.0.1`}
              </div>
            </div>
          </div>
        )}

        {/* DATA MODEL TAB */}
        {activeTab === "datamodel" && (
          <div>
            <p style={{ color: colors.textDim, fontSize: "13px", fontFamily: "monospace", marginBottom: "24px", letterSpacing: "1px" }}>
              Firestore collections — each mapped to a Dart model class with fromJson/toJson.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "16px" }}>
              {dataModels.map(model => (
                <div key={model.name} style={{ background: colors.surfaceLight, border: `1px solid ${colors.border}`, borderRadius: "12px", overflow: "hidden" }}>
                  <div style={{ background: `${model.color}22`, borderBottom: `1px solid ${model.color}44`, padding: "12px 16px", display: "flex", alignItems: "center", gap: "8px" }}>
                    <div style={{ width: "8px", height: "8px", borderRadius: "50%", background: model.color }} />
                    <span style={{ fontWeight: "700", fontSize: "13px", color: model.color, fontFamily: "monospace" }}>{model.name}</span>
                  </div>
                  <div style={{ padding: "12px 16px" }}>
                    {model.fields.map((field, i) => (
                      <div key={i} style={{ fontSize: "11px", color: field.includes(":") ? colors.goldLight : colors.textDim, fontFamily: "monospace", padding: "4px 0", borderBottom: i < model.fields.length - 1 ? `1px solid ${colors.border}` : "none" }}>{field}</div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* FLOWS TAB */}
        {activeTab === "flows" && (
          <div>
            <p style={{ color: colors.textDim, fontSize: "13px", fontFamily: "monospace", marginBottom: "24px", letterSpacing: "1px" }}>Key user flows with Flutter-specific implementation details.</p>
            {flows.map((flow, fi) => (
              <div key={fi} style={{ background: colors.surfaceLight, border: `1px solid ${colors.border}`, borderRadius: "14px", marginBottom: "16px", overflow: "hidden" }}>
                <div style={{ background: `${flow.color}11`, borderBottom: `1px solid ${flow.color}33`, padding: "14px 20px", display: "flex", alignItems: "center", gap: "12px" }}>
                  <span style={{ fontSize: "20px" }}>{flow.icon}</span>
                  <div>
                    <div style={{ fontWeight: "700", color: flow.color, fontSize: "14px" }}>{flow.title}</div>
                    <div style={{ fontSize: "11px", color: colors.textMuted, fontFamily: "monospace" }}>Actor: {flow.actor}</div>
                  </div>
                </div>
                <div style={{ padding: "16px 20px" }}>
                  {flow.steps.map((step, si) => (
                    <div key={si} style={{ display: "flex", gap: "14px", alignItems: "flex-start", marginBottom: si < flow.steps.length - 1 ? "10px" : "0" }}>
                      <div style={{ width: "22px", height: "22px", flexShrink: 0, background: `${flow.color}22`, border: `1px solid ${flow.color}55`, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "10px", color: flow.color, fontFamily: "monospace", fontWeight: "700" }}>{si + 1}</div>
                      <span style={{ fontSize: "12px", color: colors.textDim, fontFamily: "monospace", lineHeight: "1.7", paddingTop: "2px" }}>{step}</span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={{ borderTop: `1px solid ${colors.border}`, padding: "16px 40px", display: "flex", justifyContent: "space-between", alignItems: "center", background: colors.surface }}>
        <span style={{ fontSize: "11px", color: colors.textMuted, fontFamily: "monospace" }}>KWAYAPRO — Flutter Native · Uganda → East Africa</span>
        <span style={{ fontSize: "11px", color: colors.textMuted, fontFamily: "monospace" }}>MVP v2.0 · Android First · Flutter + Firebase + Cloudflare R2</span>
      </div>
    </div>
  );
}