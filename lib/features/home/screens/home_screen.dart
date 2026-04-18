import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/theme_provider.dart';
import '../../gallery/screens/gallery_screen.dart';
import '../../music/screens/music_screen.dart';
import '../../music/widgets/mini_player_widget.dart';
import '../../vault/screens/vault_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;

  // Lazy page list — keep state alive with AutomaticKeepAliveClientMixin.
  static const List<Widget> _pages = [
    GalleryScreen(showVideos: false), // Photos
    GalleryScreen(showVideos: true),  // Videos
    MusicScreen(),                    // Music
    VaultScreen(),                    // Vault
  ];

  static const List<String> _titles = [
    AppStrings.navPhotos,
    AppStrings.navVideos,
    AppStrings.navMusic,
    AppStrings.navVault,
  ];

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // ── App Bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              _titles[_currentTab],
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // Search feature can be extended here.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // Theme toggle
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: themeNotifier.toggle,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body with PageView to keep state alive ─────────────────────────
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: _pages,
            ),
          ),
          // Mini player slides up when music is playing
          const MiniPlayerWidget(),
        ],
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        height: 68,
        labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_outlined),
            selectedIcon: const Icon(Icons.photo_rounded),
            label: AppStrings.navPhotos,
            tooltip: AppStrings.navPhotos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.videocam_outlined),
            selectedIcon: const Icon(Icons.videocam_rounded),
            label: AppStrings.navVideos,
            tooltip: AppStrings.navVideos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.music_note_outlined),
            selectedIcon: const Icon(Icons.music_note_rounded),
            label: AppStrings.navMusic,
            tooltip: AppStrings.navMusic,
          ),
          NavigationDestination(
            icon: const Icon(Icons.lock_outline_rounded),
            selectedIcon: const Icon(Icons.lock_rounded),
            label: AppStrings.navVault,
            tooltip: AppStrings.navVault,
          ),
        ],
      ),
    );
  }
}
