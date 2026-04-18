// lib/features/music/widgets/mini_player_widget.dart
//
// Persistent mini-player shown above the bottom nav bar on all tabs.
// No on_audio_query dependency — reads state from audio_service streams.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/music_provider.dart';
import '../screens/music_player_screen.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentItem =
        ref.watch(currentMediaItemProvider).valueOrNull;
    final isPlaying = ref.watch(isPlayingProvider);
    final progress = ref.watch(playbackProgressProvider);

    // Show nothing when no track is queued
    if (currentItem == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E35) : Colors.white;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
      ),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Thin progress line ──────────────────────────────────
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: AppColors.primary,
              minHeight: 2,
            ),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    // Art placeholder (no album art without on_audio_query)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.musicGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.music_note_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Title & artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentItem.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentItem.artist ?? 'Unknown Artist',
                            style:
                            Theme.of(context).textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Previous
                    _MiniBtn(
                      icon: Icons.skip_previous_rounded,
                      onPressed: skipToPrevious,
                    ),

                    // Play / Pause
                    _PlayPauseCircle(isPlaying: isPlaying),

                    // Next
                    _MiniBtn(
                      icon: Icons.skip_next_rounded,
                      onPressed: skipToNext,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact icon button
// ─────────────────────────────────────────────────────────────────────────────

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _MiniBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 26,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular play/pause button
// ─────────────────────────────────────────────────────────────────────────────

class _PlayPauseCircle extends StatelessWidget {
  final bool isPlaying;
  const _PlayPauseCircle({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: togglePlayPause,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}