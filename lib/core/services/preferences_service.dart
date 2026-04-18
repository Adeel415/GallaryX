import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists app preferences using Hive.
class PreferencesService {
  static const String _settingsBox = 'settings';
  static const String _vaultBox = 'vault_files';
  static const String _favoritesBox = 'favorites';

  static const String _kThemeMode = 'theme_mode';
  static const String _kVaultPin = 'vault_pin';
  static const String _kVaultSetup = 'vault_setup';

  static Box<dynamic>? _settings;
  static Box<dynamic>? _vault;
  static Box<dynamic>? _favorites;

  /// Call once at app startup.
  static Future<void> init() async {
    _settings = await Hive.openBox<dynamic>(_settingsBox);
    _vault = await Hive.openBox<dynamic>(_vaultBox);
    _favorites = await Hive.openBox<dynamic>(_favoritesBox);
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
  static int getThemeMode() =>
      _settings?.get(_kThemeMode, defaultValue: 0) as int? ?? 0;

  static Future<void> setThemeMode(int mode) =>
      _settings!.put(_kThemeMode, mode);

  // ── Vault PIN ─────────────────────────────────────────────────────────────
  static bool get isVaultSetUp =>
      _settings?.get(_kVaultSetup, defaultValue: false) as bool? ?? false;

  /// Hash the PIN with SHA-256 and store it.
  static Future<void> setVaultPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _settings!.put(_kVaultPin, hash);
    await _settings!.put(_kVaultSetup, true);
  }

  /// Returns true if the given PIN matches the stored hash.
  static bool verifyVaultPin(String pin) {
    final stored = _settings?.get(_kVaultPin) as String?;
    if (stored == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return hash == stored;
  }

  /// Reset vault PIN and setup state.
  static Future<void> resetVault() async {
    await _settings!.delete(_kVaultPin);
    await _settings!.put(_kVaultSetup, false);
    await _vault!.clear();
  }

  // ── Vault Files ───────────────────────────────────────────────────────────
  /// Store vault file metadata as JSON string, keyed by vault path.
  static Future<void> addVaultFile(Map<String, dynamic> meta) async {
    await _vault!.put(meta['vaultPath'], jsonEncode(meta));
  }

  static Future<void> removeVaultFile(String vaultPath) async {
    await _vault!.delete(vaultPath);
  }

  static List<Map<String, dynamic>> getVaultFiles() {
    return _vault!.values
        .map((v) => Map<String, dynamic>.from(jsonDecode(v as String)))
        .toList();
  }

  // ── Favorites ─────────────────────────────────────────────────────────────
  static bool isFavorite(String assetId) =>
      _favorites?.containsKey(assetId) ?? false;

  static Future<void> toggleFavorite(String assetId) async {
    if (isFavorite(assetId)) {
      await _favorites!.delete(assetId);
    } else {
      await _favorites!.put(assetId, true);
    }
  }

  static List<String> getFavoriteIds() =>
      (_favorites?.keys.toList() ?? []).cast<String>();
}
