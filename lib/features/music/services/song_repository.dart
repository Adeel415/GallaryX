// lib/features/music/services/song_repository.dart
//
// Replaces on_audio_query.
//
// Responsibilities:
//  1. Open a file picker so the user can choose audio files.
//  2. Probe each file for its duration using a throwaway AudioPlayer.
//  3. Persist the song library to Hive across sessions.
//  4. Provide CRUD operations (add, remove, clear, reorder).

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../models/song_model.dart';

// ── Supported audio extensions ────────────────────────────────────────────────
const _audioExtensions = [
  'mp3', 'flac', 'aac', 'm4a', 'wav', 'ogg', 'opus', 'wma', 'aiff',
];

class SongRepository {
  static const String _hiveBox = 'music_library';
  static const String _hiveKey = 'songs';

  // ── Hive box reference ────────────────────────────────────────────────────
  static Box<dynamic>? _box;

  /// Call once at app startup (after Hive.initFlutter()).
  static Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_hiveBox);
  }

  // ── Load from Hive ────────────────────────────────────────────────────────

  /// Return the persisted song list. Songs whose files no longer exist are
  /// filtered out automatically.
  static List<SongModel> loadAll() {
    final raw = _box?.get(_hiveKey);
    if (raw == null) return [];

    final List<dynamic> list = raw is List ? raw : jsonDecode(raw as String);

    return list
        .map((e) => SongModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((s) => File(s.path).existsSync())
        .toList();
  }

  // ── Persist to Hive ───────────────────────────────────────────────────────

  static Future<void> _saveAll(List<SongModel> songs) async {
    final encoded = songs.map((s) => s.toMap()).toList();
    await _box?.put(_hiveKey, jsonEncode(encoded));
  }

  // ── File picker ───────────────────────────────────────────────────────────

  /// Open the system file picker filtered to audio files.
  /// Returns the list of newly added songs (already merged into [existing]).
  ///
  /// Duration is probed asynchronously per file using a throwaway AudioPlayer.
  static Future<List<SongModel>> pickAndAddSongs(
      List<SongModel> existing,
      ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
      allowMultiple: true,
      withData: false,      // we only need paths, not bytes
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return existing;

    // Deduplicate against already-stored paths
    final existingPaths = existing.map((s) => s.path).toSet();
    final newPaths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((path) => !existingPaths.contains(path))
        .toList();

    if (newPaths.isEmpty) return existing;

    // Build SongModels (with duration probing)
    final newSongs = await Future.wait(
      newPaths.map((path) => _buildSong(path)),
    );

    final updated = [...existing, ...newSongs];
    await _saveAll(updated);
    return updated;
  }

  // ── Remove a single song ──────────────────────────────────────────────────

  static Future<List<SongModel>> removeSong(
      List<SongModel> current,
      String path,
      ) async {
    final updated = current.where((s) => s.path != path).toList();
    await _saveAll(updated);
    return updated;
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await _box?.delete(_hiveKey);
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  static Future<List<SongModel>> reorder(
      List<SongModel> songs,
      int oldIndex,
      int newIndex,
      ) async {
    final list = List.of(songs);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    await _saveAll(list);
    return list;
  }

  // ── Duration probing ──────────────────────────────────────────────────────

  /// Creates a temporary AudioPlayer, loads the file silently, reads its
  /// duration, then disposes. Falls back to 0 ms on any error.
  static Future<SongModel> _buildSong(String filePath) async {
    final base = SongModel.fromPath(filePath);
    final player = AudioPlayer();
    try {
      final source = AudioSource.uri(Uri.file(filePath));
      await player.setAudioSource(source);
      final dur = player.duration;
      await player.dispose();
      return base.copyWith(durationMs: dur?.inMilliseconds ?? 0);
    } catch (_) {
      await player.dispose();
      return base;
    }
  }

  // ── Convenience: file extension check ────────────────────────────────────

  static bool isAudioFile(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return _audioExtensions.contains(ext);
  }
}