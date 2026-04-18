// lib/features/music/screens/music_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/file_utils.dart';
import '../../../widgets/empty_state_widget.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SongModel> _filter(List<SongModel> songs) {
    if (_query.isEmpty) return songs;
    final q = _query.toLowerCase();
    return songs
        .where((s) =>
    s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickSongs() async {
    await ref.read(songLibraryProvider.notifier).pickSongs();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Library?'),
        content: const Text(
            'All songs will be removed from the list. '
                'Your actual audio files will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(songLibraryProvider.notifier).clearLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libState = ref.watch(songLibraryProvider);
    final currentItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final isPlaying = ref.watch(isPlayingProvider);
    final filtered = _filter(libState.songs);

    return Scaffold(
      body: Column(
        children: [
          // ── Toolbar ────────────────────────────────────────────────────
          _MusicToolbar(
            songCount: filtered.length,
            isPickingFiles: libState.isPickingFiles,
            hasError: libState.error != null,
            errorMsg: libState.error,
            hasSongs: libState.songs.isNotEmpty,
            onClear: _confirmClear,
            onShuffleAll: filtered.isEmpty
                ? null
                : () async {
              final shuffled = List.of(filtered)..shuffle();
              await playSong(shuffled.first, shuffled);
            },
          ),

          // ── Search bar ────────────────────────────────────────────────
          if (libState.songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.primary),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                      : null,
                ),
              ),
            ),

          // ── Song list or empty state ───────────────────────────────────
          Expanded(
            child: libState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : libState.songs.isEmpty
                ? _EmptyMusicState(onPickFiles: _pickSongs)
                : filtered.isEmpty
                ? EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'No results',
              subtitle: 'No songs match "$_query"',
            )
                : AnimationLimiter(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final song = filtered[i];
                  final songUri =
                  Uri.file(song.path).toString();
                  final isCurrent =
                      currentItem?.id == songUri;

                  return AnimationConfiguration
                      .staggeredList(
                    position: i,
                    duration:
                    const Duration(milliseconds: 280),
                    child: SlideAnimation(
                      verticalOffset: 20,
                      child: FadeInAnimation(
                        child: _SongTile(
                          song: song,
                          isCurrent: isCurrent,
                          isPlaying:
                          isCurrent && isPlaying,
                          allSongs: filtered,
                          onTap: () =>
                              playSong(song, filtered),
                          onRemove: () => ref
                              .read(songLibraryProvider
                              .notifier)
                              .removeSong(song.path),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // ── FAB: Add Songs ─────────────────────────────────────────────────
      floatingActionButton: libState.isPickingFiles
          ? const FloatingActionButton(
        onPressed: null,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        ),
      )
          : FloatingActionButton.extended(
        onPressed: _pickSongs,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Songs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar row
// ─────────────────────────────────────────────────────────────────────────────

class _MusicToolbar extends StatelessWidget {
  final int songCount;
  final bool isPickingFiles;
  final bool hasError;
  final String? errorMsg;
  final bool hasSongs;
  final VoidCallback? onShuffleAll;
  final VoidCallback onClear;

  const _MusicToolbar({
    required this.songCount,
    required this.isPickingFiles,
    required this.hasError,
    required this.errorMsg,
    required this.hasSongs,
    required this.onShuffleAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Text(
            '$songCount song${songCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (hasError) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: errorMsg ?? 'Unknown error',
              child: const Icon(Icons.error_outline,
                  color: Colors.red, size: 18),
            ),
          ],
          const Spacer(),
          if (onShuffleAll != null)
            TextButton.icon(
              onPressed: onShuffleAll,
              icon: const Icon(Icons.shuffle_rounded,
                  size: 18, color: AppColors.primary),
              label: const Text('Shuffle',
                  style: TextStyle(color: AppColors.primary)),
            ),
          if (hasSongs)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear library',
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state with prominent Add Songs prompt
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMusicState extends StatelessWidget {
  final VoidCallback onPickFiles;

  const _EmptyMusicState({required this.onPickFiles});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.library_music_outlined,
                  size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Your music library is empty',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to pick audio files from your device.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onPickFiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Songs'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Supported formats: MP3, FLAC, AAC, M4A, WAV, OGG …',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Song tile with swipe-to-delete
// ─────────────────────────────────────────────────────────────────────────────

class _SongTile extends StatelessWidget {
  final SongModel song;
  final bool isCurrent;
  final bool isPlaying;
  final List<SongModel> allSongs;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SongTile({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.allSongs,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(song.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onRemove(),
      child: Material(
        color: isCurrent
            ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // ── Art placeholder ──────────────────────────────────
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isCurrent
                        ? AppColors.primaryGradient
                        : AppColors.musicGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.music_note_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 12),

                // ── Title + meta ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          song.artist,
                          if (song.durationMs > 0)
                            FileUtils.formatDuration(
                                song.durationMs ~/ 1000),
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),

                // ── EQ icon while playing ────────────────────────────
                if (isPlaying)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.equalizer_rounded,
                        color: AppColors.primary, size: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}