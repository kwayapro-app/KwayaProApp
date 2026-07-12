import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/audio_player_notifier.dart';
import '../../../../shared/models/enums.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPart = ref.watch(audioPlayerProvider.select((s) => s.currentPart));

    if (currentPart == null) {
      return const SizedBox.shrink();
    }

    final currentSong = ref.watch(audioPlayerProvider.select((s) => s.currentSong))!;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ErrorBanner(theme: theme),
        Container(
          height: 68,
          clipBehavior: Clip.antiAlias,
          // M3 SHAPE COMPLIANCE FOLLOW-UP FIX: this Container had no shape at
          // all (sharp default corners), inconsistent with the rest of the
          // app's M3 Expressive rounded-corner language defined in
          // app_theme.dart. Reusing the Card token (24dp — see
          // `cardTheme.shape` in app_theme.dart, also used for the song
          // cards this bar sits directly below in library_screen.dart /
          // song_list_item.dart) rather than inventing a new radius. Only
          // the top corners are rounded, matching the same top-only idiom
          // app_theme.dart's bottomSheetTheme and home_screen.dart's choir
          // switcher sheet use for surfaces anchored to the bottom edge —
          // the bottom edge here sits flush above the NavigationBar, not a
          // floating edge, so it stays square.
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Seek bar — CHORISTER AUDIT FIX: this was a non-interactive
              // LinearProgressIndicator (display-only, no seek control
              // existed anywhere in the player). A Slider is the standard
              // Material seek control and reuses the same position/duration
              // state AudioPlayerNotifier now actually keeps updated.
              // Scoped to its own Consumer so the ~200ms position ticks only
              // rebuild this Slider, not the buttons/text below it.
              SizedBox(
                height: 12,
                child: Consumer(
                  builder: (context, ref, _) {
                    final position = ref.watch(audioPlayerProvider.select((s) => s.position));
                    final duration = ref.watch(audioPlayerProvider.select((s) => s.duration));
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: theme.colorScheme.surfaceContainerHighest,
                        onChanged: duration.inMilliseconds > 0
                            ? (value) {
                                ref.read(audioPlayerProvider.notifier).seek(
                                      Duration(milliseconds: (value * duration.inMilliseconds).round()),
                                    );
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
              // Controls
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Song info
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            // Could navigate to full player
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${currentPart.voicePart.displayName} Part',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Speed button — CHORISTER AUDIT FOLLOW-UP FIX: this was
                      // a TextButton, which reliably crashed Flutter's
                      // rendering pipeline in this exact spot (a Row inside a
                      // fixed 68px-tall Container) with a
                      // `!semantics.parentDataDirty` assertion on every
                      // rebuild — reproduced with a bare, hardcoded
                      // TextButton with no app logic at all, so it's a
                      // TextButton-specific framework issue on this Flutter
                      // version, not anything about our state or providers.
                      // Confirmed via `flutter run`'s raw stdout (adb
                      // logcat's `I/flutter` filtering hides these — that's
                      // why the original audit's logcat-only check missed
                      // it). Flutter's default error zone swallows the
                      // exception and aborts that frame's paint, so nothing
                      // in this Container ever rendered even though state and
                      // build() were both correct. An IconButton in the same
                      // exact spot does not trigger it, so the speed control
                      // is now an InkWell-wrapped label instead of
                      // TextButton — same tap target, ripple, and text style,
                      // without TextButton's internal machinery.
                      Consumer(
                        builder: (context, ref, _) {
                          final speed = ref.watch(audioPlayerProvider.select((s) => s.playbackSpeed));
                          // M3 SHAPE COMPLIANCE FOLLOW-UP FIX: StadiumBorder
                          // here already matches app_theme.dart's button
                          // token (pill shape, see filledButtonTheme /
                          // outlinedButtonTheme / textButtonTheme, all
                          // `BorderRadius.circular(50)` — a StadiumBorder is
                          // that same pill shape expressed without a fixed
                          // radius number). What was missing was
                          // `clipBehavior` — a Material's `shape` alone only
                          // affects its own painted background, it doesn't
                          // clip descendant InkWell ripples to that shape by
                          // default, so the ripple could bleed past the
                          // pill's rounded ends into a rectangle.
                          return Material(
                            color: Colors.transparent,
                            shape: const StadiumBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => _showSpeedSelector(context, ref),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  '${speed}x',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Repeat toggle
                      Consumer(
                        builder: (context, ref, _) {
                          final isRepeat = ref.watch(audioPlayerProvider.select((s) => s.isRepeat));
                          return IconButton(
                            icon: Icon(
                              Icons.repeat,
                              color: isRepeat
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).toggleRepeat();
                            },
                          );
                        },
                      ),

                      // Play/Pause
                      Consumer(
                        builder: (context, ref, _) {
                          final isPlaying = ref.watch(audioPlayerProvider.select((s) => s.isPlaying));
                          final isLoading = ref.watch(audioPlayerProvider.select((s) => s.isLoading));
                          if (isLoading) {
                            return const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          // CHORISTER AUDIT FOLLOW-UP FIX: IconButton.filled
                          // showed the same partial-render symptom as
                          // TextButton in this exact spot (a Row inside a
                          // fixed 68px-tall Container) — the icon painted as
                          // a barely-visible sliver instead of the full
                          // play/pause glyph on its filled circle, even
                          // though state and onPressed both worked (tapping
                          // the sliver's location did toggle playback). Its
                          // filled/elevated state-layer widget tree is more
                          // complex than a plain IconButton's, similar to
                          // what made TextButton crash outright here.
                          // Replaced with a plain IconButton on top of a
                          // manually drawn filled circle — same M3 "filled
                          // icon button" look, without that extra machinery.
                          // M3 SHAPE COMPLIANCE FOLLOW-UP FIX: BoxShape.circle
                          // is already the correct M3 "filled icon button"
                          // shape (matches what IconButton.filled itself
                          // draws), but a plain Container doesn't clip its
                          // child by default — the IconButton's own ripple
                          // could paint square corners peeking out past the
                          // circle underneath. ClipOval guarantees the
                          // ripple is bounded to the same circle.
                          return ClipOval(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    ref.read(audioPlayerProvider.notifier).pause();
                                  } else {
                                    ref.read(audioPlayerProvider.notifier).resume();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      // Close
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          ref.read(audioPlayerProvider.notifier).stop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSpeedSelector(BuildContext context, WidgetRef ref) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
    final currentSpeed = ref.read(audioPlayerProvider).playbackSpeed;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Playback Speed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...speeds.map(
              (speed) => ListTile(
                title: Text('${speed}x'),
                trailing: currentSpeed == speed
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref.read(audioPlayerProvider.notifier).setSpeed(speed);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Playback errors (e.g. offline + not yet cached) were previously stored in
// AudioPlayerState.error but never shown anywhere — silently swallowed.
// Scoped to its own Consumer so it doesn't force the rest of the bar to
// rebuild when an error is set/cleared.
class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(audioPlayerProvider.select((s) => s.error));
    if (error == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        error,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
