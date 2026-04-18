// lib/features/music/services/audio_handler.dart
//
// SmartGalleryAudioHandler
// ════════════════════════
// Bridges just_audio ↔ audio_service.
// No on_audio_query dependency anywhere in this file.
//
// Provides:
//   • Background playback (survives app minimise / screen off)
//   • Lock-screen / notification media controls
//   • Headset button handling (play/pause, next, previous)
//   • Queue management with shuffle & repeat
//   • Seek, fast-forward, rewind

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Global handler singleton — initialised once in main() via [initAudioService].
late SmartGalleryAudioHandler audioHandler;

/// Initialise audio_service and return the handler.
/// **Must be called before runApp().**
Future<SmartGalleryAudioHandler> initAudioService() async {
  final handler = await AudioService.init<SmartGalleryAudioHandler>(
    builder: () => SmartGalleryAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
      'com.example.smart_gallery_app.audio',
      androidNotificationChannelName: 'Smart Gallery Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      rewindInterval: Duration(seconds: 10),
      fastForwardInterval: Duration(seconds: 10),
      artDownscaleWidth: 300,
      artDownscaleHeight: 300,
    ),
  );
  audioHandler = handler;
  return handler;
}

// ─────────────────────────────────────────────────────────────────────────────

class SmartGalleryAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  // ── just_audio player ──────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Internal queue mirror ──────────────────────────────────────────────
  List<MediaItem> _queue = [];
  int _currentIndex = 0;

  SmartGalleryAudioHandler() {
    _wireStreams();
  }

  // ── Wire just_audio streams → audio_service broadcasts ─────────────────
  void _wireStreams() {
    // Playback events → notification controls state
    _player.playbackEventStream.listen(_broadcastState);

    // Current index change → update mediaItem
    _player.currentIndexStream.listen((idx) {
      if (idx != null && idx < _queue.length) {
        _currentIndex = idx;
        mediaItem.add(_queue[idx]);
      }
    });

    // Duration update → patch the current MediaItem
    _player.durationStream.listen((dur) {
      final current = mediaItem.value;
      if (current != null && dur != null) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    });

    // Auto-advance on natural completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onComplete();
    });
  }

  // ── Public: load a new queue and start playing ─────────────────────────

  Future<void> loadQueue({
    required List<MediaItem> items,
    int startIndex = 0,
  }) async {
    if (items.isEmpty) return;

    _queue = List.of(items);
    _currentIndex = startIndex.clamp(0, items.length - 1);

    // Publish queue and initial item to audio_service streams
    queue.add(_queue);
    mediaItem.add(_queue[_currentIndex]);

    final sources = _queue
        .map((item) => AudioSource.uri(Uri.parse(item.id)))
        .toList();

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (e) {
      // Skip unplayable file and try the next one
      if (_currentIndex < _queue.length - 1) {
        await skipToNext();
      }
    }
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() =>
      _player.seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() =>
      _player.seek(_player.position - const Duration(seconds: 10));

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    final next = (_currentIndex + 1) % _queue.length;
    await _player.seek(Duration.zero, index: next);
    if (!_player.playing) await _player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      final prev =
          (_currentIndex - 1 + _queue.length) % _queue.length;
      await _player.seek(Duration.zero, index: prev);
      if (!_player.playing) await _player.play();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    mediaItem.add(_queue[index]);
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) await _player.play();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    await _player.setShuffleModeEnabled(
        mode == AudioServiceShuffleMode.all);
    playbackState.add(
        playbackState.value.copyWith(shuffleMode: mode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    LoopMode loop;
    switch (mode) {
      case AudioServiceRepeatMode.one:
        loop = LoopMode.one;
        break;
      case AudioServiceRepeatMode.all:
        loop = LoopMode.all;
        break;
      default:
        loop = LoopMode.off;
    }
    await _player.setLoopMode(loop);
    playbackState.add(
        playbackState.value.copyWith(repeatMode: mode));
  }

  // ── Disposal ──────────────────────────────────────────────────────────

  @override
  Future<void> customAction(
      String name, [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') {
      await _player.dispose();
      await super.stop();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _onComplete() {
    final repeat = playbackState.value.repeatMode;
    if (repeat == AudioServiceRepeatMode.one) return;
    skipToNext();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final controls = [
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _processingState(),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: _toServiceRepeat(_player.loopMode),
    ));
  }

  AudioProcessingState _processingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _toServiceRepeat(LoopMode mode) {
    switch (mode) {
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
      default:
        return AudioServiceRepeatMode.none;
    }
  }

  // ── Raw stream access for UI (position slider etc.) ───────────────────
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  int get currentIndex => _currentIndex;
  List<MediaItem> get currentQueue => List.unmodifiable(_queue);
}