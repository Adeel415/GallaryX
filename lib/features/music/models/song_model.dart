// lib/features/music/models/song_model.dart
//
// Pure-Dart song model.
// No on_audio_query dependency — all fields are populated from:
//   • The file path (title parsed from filename)
//   • just_audio (duration probed at import time)
//   • Hive (persisted across sessions)

import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as p;

class SongModel {
  /// Unique key — the absolute file path (also used as MediaItem id via URI).
  final String path;

  /// Display title. Derived from the filename when no ID3 data is available.
  final String title;

  /// Artist string, defaults to "Unknown Artist".
  final String artist;

  /// Album string, defaults to "Unknown Album".
  final String album;

  /// Duration in milliseconds. 0 if not yet probed.
  final int durationMs;

  const SongModel({
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.durationMs = 0,
  });

  // ── Factory: build from raw file path ──────────────────────────────────
  factory SongModel.fromPath(String filePath, {int durationMs = 0}) {
    final raw = p.basenameWithoutExtension(filePath);
    // Replace common separators with spaces and title-case the result.
    final title = raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .trim();

    return SongModel(
      path: filePath,
      title: title.isEmpty ? 'Unknown Track' : title,
      durationMs: durationMs,
    );
  }

  // ── Hive serialisation ──────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
  };

  factory SongModel.fromMap(Map<String, dynamic> map) => SongModel(
    path: map['path'] as String,
    title: map['title'] as String? ?? 'Unknown Track',
    artist: map['artist'] as String? ?? 'Unknown Artist',
    album: map['album'] as String? ?? 'Unknown Album',
    durationMs: map['durationMs'] as int? ?? 0,
  );

  SongModel copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
  }) =>
      SongModel(
        path: path ?? this.path,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        durationMs: durationMs ?? this.durationMs,
      );

  // ── Convert to audio_service MediaItem ──────────────────────────────────
  // The MediaItem.id is the file URI so AudioSource.uri() can open it directly.
  MediaItem toMediaItem() => MediaItem(
    id: Uri.file(path).toString(),
    title: title,
    artist: artist,
    album: album,
    duration:
    durationMs > 0 ? Duration(milliseconds: durationMs) : null,
    extras: {'filePath': path},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SongModel && other.path == path);

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'SongModel(title: $title, artist: $artist)';
}