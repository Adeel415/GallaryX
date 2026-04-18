// lib/features/music/providers/music_provider.dart
//
// All Riverpod providers for the music feature.
// Uses SongRepository (file_picker + Hive) instead of on_audio_query.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../services/song_repository.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. Song Library  (SongRepository → Hive)
// ═════════════════════════════════════════════════════════════════════════════

/// State notifier that owns the user's song library.
class SongLibraryNotifier extends StateNotifier<SongLibraryState> {
  SongLibraryNotifier() : super(SongLibraryState.initial()) {
    _load();
  }

  // ── Load persisted songs on startup ──────────────────────────────────────

  void _load() {
    final songs = SongRepository.loadAll();
    state = state.copyWith(songs: songs, isLoading: false);
  }

  // ── Pick new files from device ────────────────────────────────────────────

  Future<void> pickSongs() async {
    state = state.copyWith(isPickingFiles: true, error: null);
    try {
      final updated =
      await SongRepository.pickAndAddSongs(state.songs);
      state = state.copyWith(songs: updated, isPickingFiles: false);
    } catch (e) {
      state = state.copyWith(
        isPickingFiles: false,
        error: 'Could not import files: $e',
      );
    }
  }

  // ── Remove a single song ──────────────────────────────────────────────────

  Future<void> removeSong(String path) async {
    final updated =
    await SongRepository.removeSong(state.songs, path);
    state = state.copyWith(songs: updated);
  }

  // ── Clear entire library ──────────────────────────────────────────────────

  Future<void> clearLibrary() async {
    await SongRepository.clearAll();
    state = state.copyWith(songs: []);
  }

  // ── Reorder (drag-and-drop) ───────────────────────────────────────────────

  Future<void> reorder(int oldIndex, int newIndex) async {
    final updated =
    await SongRepository.reorder(state.songs, oldIndex, newIndex);
    state = state.copyWith(songs: updated);
  }
}

// ── State model ───────────────────────────────────────────────────────────────

class SongLibraryState {
  final List<SongModel> songs;
  final bool isLoading;
  final bool isPickingFiles;
  final String? error;

  const SongLibraryState({
    required this.songs,
    required this.isLoading,
    required this.isPickingFiles,
    this.error,
  });

  factory SongLibraryState.initial() => const SongLibraryState(
    songs: [],
    isLoading: true,
    isPickingFiles: false,
  );

  SongLibraryState copyWith({
    List<SongModel>? songs,
    bool? isLoading,
    bool? isPickingFiles,
    String? error,
  }) =>
      SongLibraryState(
        songs: songs ?? this.songs,
        isLoading: isLoading ?? this.isLoading,
        isPickingFiles: isPickingFiles ?? this.isPickingFiles,
        error: error,
      );
}

/// Primary provider for the user's song library.
final songLibraryProvider =
StateNotifierProvider<SongLibraryNotifier, SongLibraryState>(
      (ref) => SongLibraryNotifier(),
);

/// Convenience provider for the raw song list.
final songListProvider = Provider<List<SongModel>>((ref) {
  return ref.watch(songLibraryProvider).songs;
});

// ═════════════════════════════════════════════════════════════════════════════
// 2. audio_service stream providers
// ═════════════════════════════════════════════════════════════════════════════

/// Currently playing MediaItem (null when nothing is queued).
final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return audioHandler.mediaItem.stream;
});

/// Full PlaybackState (playing flag, position, shuffle, repeat, controls …).
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return audioHandler.playbackState.stream;
});

/// Playback position — updates continuously while playing.
final positionProvider = StreamProvider<Duration>((ref) {
  return audioHandler.positionStream;
});

/// Duration of the current track.
final durationProvider = StreamProvider<Duration?>((ref) {
  return audioHandler.durationStream;
});

/// Queue as reported by the handler (MediaItem list).
final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  return audioHandler.queue.stream;
});

// ═════════════════════════════════════════════════════════════════════════════
// 3. Derived convenience providers
// ═════════════════════════════════════════════════════════════════════════════

/// True while audio is actively playing.
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;
});

/// Seek bar value: 0.0 – 1.0.
final playbackProgressProvider = Provider<double>((ref) {
  final pos =
      ref.watch(positionProvider).valueOrNull ?? Duration.zero;
  final dur =
      ref.watch(durationProvider).valueOrNull ?? Duration.zero;
  if (dur.inMilliseconds == 0) return 0;
  return (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
});

/// Whether shuffle mode is enabled.
final isShuffleProvider = Provider<bool>((ref) {
  final state = ref.watch(playbackStateProvider).valueOrNull;
  return state?.shuffleMode == AudioServiceShuffleMode.all;
});

/// Current repeat mode.
final repeatModeProvider = Provider<AudioServiceRepeatMode>((ref) {
  final state = ref.watch(playbackStateProvider).valueOrNull;
  return state?.repeatMode ?? AudioServiceRepeatMode.none;
});

/// Processing state (loading / buffering / ready …).
final processingStateProvider = Provider<AudioProcessingState>((ref) {
  final state = ref.watch(playbackStateProvider).valueOrNull;
  return state?.processingState ?? AudioProcessingState.idle;
});

// ═════════════════════════════════════════════════════════════════════════════
// 4. Playback action helpers
//    Thin wrappers so screens don't import audio_handler directly.
// ═════════════════════════════════════════════════════════════════════════════

/// Play a [song] from the given [queue].
Future<void> playSong(SongModel song, List<SongModel> queue) async {
  final items = queue.map((s) => s.toMediaItem()).toList();
  final startIndex =
  queue.indexWhere((s) => s.path == song.path);
  await audioHandler.loadQueue(
    items: items,
    startIndex: startIndex < 0 ? 0 : startIndex,
  );
}

/// Toggle play / pause.
Future<void> togglePlayPause() async {
  if (audioHandler.playbackState.value.playing) {
    await audioHandler.pause();
  } else {
    await audioHandler.play();
  }
}

Future<void> skipToNext() => audioHandler.skipToNext();
Future<void> skipToPrevious() => audioHandler.skipToPrevious();
Future<void> seekTo(Duration position) => audioHandler.seek(position);

Future<void> toggleShuffle() async {
  final current = audioHandler.playbackState.value.shuffleMode;
  await audioHandler.setShuffleMode(
    current == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all,
  );
}

Future<void> cycleRepeatMode() async {
  final current = audioHandler.playbackState.value.repeatMode;
  final next = switch (current) {
    AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
    AudioServiceRepeatMode.all  => AudioServiceRepeatMode.one,
    _                           => AudioServiceRepeatMode.none,
  };
  await audioHandler.setRepeatMode(next);
}