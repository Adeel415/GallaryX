// lib/features/music/screens/music_player_screen.dart

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../providers/music_provider.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() =>
      _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = ref.watch(currentMediaItemProvider).valueOrNull;
    final isPlaying = ref.watch(isPlayingProvider);
    final position =
        ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final progress = ref.watch(playbackProgressProvider);
    final isShuffle = ref.watch(isShuffleProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    final procState = ref.watch(processingStateProvider);

    // Animate disc while playing
    isPlaying ? _rotCtrl.repeat() : _rotCtrl.stop();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
      isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: currentItem == null
            ? const Center(child: Text('No track selected'))
            : Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            _TopBar(title: currentItem.title),

            const Spacer(),

            // ── Rotating disc ────────────────────────────────────
            AnimatedBuilder(
              animation: _rotCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _rotCtrl.value * 6.2832,
                child: child,
              ),
              child: _Disc(size: screenW * 0.65),
            ),

            const Spacer(),

            // ── Track info ───────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    currentItem.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentItem.artist ?? 'Unknown Artist',
                    style:
                    Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Seek bar ─────────────────────────────────────────
            _SeekBar(
              position: position,
              duration: duration,
              progress: progress,
            ),

            const SizedBox(height: 12),

            // ── Controls ─────────────────────────────────────────
            _Controls(
              isPlaying: isPlaying,
              isLoading: procState ==
                  AudioProcessingState.loading ||
                  procState == AudioProcessingState.buffering,
            ),

            const SizedBox(height: 24),

            // ── Shuffle / Repeat ─────────────────────────────────
            _ShuffleRepeatRow(
              isShuffle: isShuffle,
              repeatMode: repeatMode,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
                Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'NOW PLAYING',
                style:
                Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  final double size;
  const _Disc({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.musicGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.music_note_rounded,
          color: Colors.white70, size: 80),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double progress;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor:
              AppColors.primary.withOpacity(0.2),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.15),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final ms =
                (v * duration.inMilliseconds).round();
                seekTo(Duration(milliseconds: ms));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(FileUtils.formatDurationObj(position),
                    style:
                    Theme.of(context).textTheme.labelSmall),
                Text(FileUtils.formatDurationObj(duration),
                    style:
                    Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  const _Controls({required this.isPlaying, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: skipToPrevious,
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: togglePlayPause,
          child: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: isLoading
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
                : Icon(
              isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: skipToNext,
        ),
      ],
    );
  }
}

class _ShuffleRepeatRow extends StatelessWidget {
  final bool isShuffle;
  final AudioServiceRepeatMode repeatMode;
  const _ShuffleRepeatRow(
      {required this.isShuffle, required this.repeatMode});

  @override
  Widget build(BuildContext context) {
    final (repeatIcon, repeatColor) = switch (repeatMode) {
      AudioServiceRepeatMode.all  => (Icons.repeat_rounded,     AppColors.primary),
      AudioServiceRepeatMode.one  => (Icons.repeat_one_rounded, AppColors.primary),
      _                           => (Icons.repeat_rounded,     Colors.grey as Color),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded,
              color: isShuffle ? AppColors.primary : Colors.grey),
          onPressed: toggleShuffle,
          tooltip: 'Shuffle',
        ),
        const SizedBox(width: 48),
        IconButton(
          icon: Icon(repeatIcon, color: repeatColor),
          onPressed: cycleRepeatMode,
          tooltip: 'Repeat',
        ),
      ],
    );
  }
}