# Phase 6b Report — Real Launcher Icons

**Scope:** Android launcher icon generation/configuration only. No iOS icons touched (Associated Domains/appId remain a separate, already-flagged open item). Additive. **Not deployed** — a real device/emulator build is still needed to see the final rendering (see below).

---

## What was generated

**Source rasterization:** `flutter_launcher_icons` expects PNG inputs (not confirmed to support SVG directly per current docs, so per the task's instruction I rasterized first rather than assuming). Reused the `sharp` toolchain from Phase 6 (already proven to have working prebuilt Windows binaries, unlike the ImageMagick/cairosvg options that failed there).

- Created `kwayapro/assets/icons/kwayapro_app_icon_foreground.svg` — the existing `kwayapro_app_icon.svg` with the background `<rect>` stripped out, keeping the same 240×240 viewBox so the mark's proportions/position are unchanged. This is the foreground layer source.
- Rasterized both the full icon (background + mark) and the foreground-only mark to 1024×1024 PNGs via `sharp`, at a high source density (1536) so the SVG's rounded strokes stay smooth at that resolution.
- **Verified transparency was actually preserved, not assumed:** read the foreground PNG back as raw pixel data and checked the alpha channel directly — corner pixel alpha = 0 (fully transparent), mark-region pixel alpha = 255 (fully opaque). Confirms `sharp` correctly preserves the SVG's transparent background rather than flattening it onto white or black.
- Placed both PNGs at `kwayapro/assets/icon_source/` — deliberately **not** added to `pubspec.yaml`'s `flutter: assets:` bundling list, since these are icon-generation source material, not runtime app assets (same reasoning as Phase 6's `store_assets/`).

## Background color — sourced, not guessed

Read `docs/KwayaProBrandIndentity.html` in full, as instructed. The doc's "Implementation Snippets" section — labeled as the canonical copy-paste source, and byte-for-byte identical to the actual `kwayapro_app_icon.svg` already in the repo — uses a flat `#FFD97D` fill for the background rect (the doc's hero visual uses a `#FFD97D`→`#E8C06A` gradient for presentational polish, but the documented *implementation* asset is the flat color). Used **`#FFD97D`** as `adaptive_icon_background`, matching both the doc's designated implementation snippet and the existing SVG source exactly — not an arbitrary or improvised fill.

## Configuration

Added `flutter_launcher_icons: ^0.14.4` as a dev dependency. Verified the current config format directly against `pub.dev/packages/flutter_launcher_icons` before writing anything (key name is `flutter_launcher_icons:`, not the older `flutter_icons:`). Config added to `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon_source/icon_full_1024.png"
  adaptive_icon_background: "#FFD97D"
  adaptive_icon_foreground: "assets/icon_source/icon_foreground_1024.png"
```

`ios: false` — explicit, not just omitted, so there's no ambiguity that iOS was deliberately excluded per this phase's scope.

## What running it produced

Ran `dart run flutter_launcher_icons`. Output confirms it touched exactly what was expected — the standard/legacy launcher icon plus a real Android 8+ adaptive icon (separate foreground/background layers, not a single flattened square):

- `android/app/src/main/res/mipmap-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` — **replaced** (legacy/fallback icon for pre-Android-8 or launchers that don't support adaptive icons).
- `android/app/src/main/res/drawable-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png` — **new**, the adaptive icon's foreground layer per density.
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` — **new**, the adaptive-icon definition:
  ```xml
  <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground>
        <inset android:drawable="@drawable/ic_launcher_foreground" android:inset="16%" />
    </foreground>
  </adaptive-icon>
  ```
- `android/app/src/main/res/values/colors.xml` — **new**, `ic_launcher_background = #FFD97D`.

`AndroidManifest.xml` needed no changes — it already referenced `@mipmap/ic_launcher` (unchanged), which now resolves to real content instead of the placeholder.

---

## Verification

### 1. Real replacement confirmed, not just files touched

Snapshotted the stock placeholders before running anything — all five `mipmap-*/ic_launcher.png` files were tiny (442–1443 bytes, confirmed via `stat`/`md5sum`), matching the original audit's description of the untouched Flutter template default. After generation, the same files are meaningfully larger (1858–7748 bytes) — a real size-based diff, not just a timestamp change.

**Visually verified via the view tool, as instructed — not assumed from file sizes alone:**
- `mipmap-xxxhdpi/ic_launcher.png`: shows the real KwayaPro "K" chorister mark (dark-green head circle, brown pillar/arms) on the gold squircle background — not blank, not broken, not the Flutter default.
- `drawable-xxxhdpi/ic_launcher_foreground.png`: shows the same mark correctly inset on a transparent background, confirming the adaptive-icon foreground layer is real content too, not an empty/placeholder image.

### 2. `flutter analyze`: clean. Full `flutter test`: still **36/36 passing** — icon generation didn't touch any Dart source, so this is a pure confirmation nothing else broke, as expected.

### 3. Cannot be fully confirmed from static files alone — needs a real build

Icon generation tools produce the correct *source* PNGs and XML wiring, but Android's actual adaptive-icon rendering (the OS applying its own mask shape — circle, squircle, rounded-square, or a manufacturer-specific shape — plus parallax/motion effects on supported launchers) can only be seen by actually installing the app on a device or emulator running Android 8+. The static files here are correct and verifiable (and were verified), but **the final on-screen icon shape/cropping should be checked on a real device or emulator before considering this fully done** — flagging this explicitly rather than claiming a static-file check is equivalent to seeing the real rendered icon.

---

## Files changed this phase
- `kwayapro/pubspec.yaml` — added `flutter_launcher_icons` dev dependency + its config block.
- `kwayapro/assets/icons/kwayapro_app_icon_foreground.svg` — new, foreground-only mark source.
- `kwayapro/assets/icon_source/icon_full_1024.png`, `icon_foreground_1024.png` — new, rasterized PNG sources (not bundled into the app).
- `kwayapro/android/app/src/main/res/mipmap-*/ic_launcher.png` — replaced.
- `kwayapro/android/app/src/main/res/drawable-*/ic_launcher_foreground.png` — new.
- `kwayapro/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` — new.
- `kwayapro/android/app/src/main/res/values/colors.xml` — new.

## Open flags
- **Real device/emulator verification of the final adaptive icon rendering** — see §3 above, your action, can't be done from this environment.
- Everything else from Phase 6's open flags (assetlinks.json hosting, feature graphic, screenshots, iOS icons/Associated Domains, credential rotation) unchanged and still open.

Awaiting your review before Phase 7 (Hygiene + Test Coverage), the final phase of this pass.
