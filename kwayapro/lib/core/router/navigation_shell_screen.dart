import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../features/audio/presentation/widgets/mini_player_bar.dart';

class NavigationShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // CHORISTER AUDIT FOLLOW-UP FIX: MiniPlayerBar used to be placed via
      // library_screen.dart's `Scaffold.bottomSheet`, which never actually
      // rendered — confirmed visually on-device that tapping a voice part
      // started real playback (position/state updates streaming) but no
      // player UI ever appeared. Scaffold.bottomSheet is a persistent-sheet
      // -controller mechanism (the same API `showBottomSheet` uses), not a
      // normal reactive widget slot. It was also scoped to only the Library
      // tab's own nested Scaffold, so even if it had rendered, it would have
      // vanished the moment a chorister switched tabs mid-song. Moving it
      // here — a plain Column between the shell content and the bottom nav
      // bar — fixes both: normal widget rebuilds react to state changes the
      // way any other widget does, and it now persists across all four tabs.
      body: Column(
        children: [
          Expanded(child: OfflineBanner(child: navigationShell)),
          const MiniPlayerBar(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        indicatorColor: colorScheme.secondaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Rehearsals',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
