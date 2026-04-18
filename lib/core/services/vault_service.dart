import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'preferences_service.dart';

/// Model representing a file stored in the vault.
class VaultFile {
  final String id;
  final String originalPath;
  final String vaultPath;
  final String fileName;
  final String mediaType; // 'image' | 'video'
  final int sizeBytes;
  final DateTime dateAdded;

  const VaultFile({
    required this.id,
    required this.originalPath,
    required this.vaultPath,
    required this.fileName,
    required this.mediaType,
    required this.sizeBytes,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'originalPath': originalPath,
        'vaultPath': vaultPath,
        'fileName': fileName,
        'mediaType': mediaType,
        'sizeBytes': sizeBytes,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
      };

  factory VaultFile.fromMap(Map<String, dynamic> map) => VaultFile(
        id: map['id'] as String,
        originalPath: map['originalPath'] as String,
        vaultPath: map['vaultPath'] as String,
        fileName: map['fileName'] as String,
        mediaType: map['mediaType'] as String,
        sizeBytes: map['sizeBytes'] as int,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int),
      );

  File get file => File(vaultPath);
}

/// Service to move files into/out of the app's private vault directory.
class VaultService {
  /// Returns the vault directory, creating it if needed.
  static Future<Directory> get vaultDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, '.vault'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Move an [AssetEntity] into the vault.
  /// Returns the [VaultFile] if successful, null otherwise.
  static Future<VaultFile?> moveToVault(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return null;

      final dir = await vaultDir;
      // Prefix with timestamp to avoid name collisions.
      final vaultFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final vaultPath = p.join(dir.path, vaultFileName);

      // Copy to vault directory.
      await file.copy(vaultPath);

      // Delete original from gallery (requires WRITE_EXTERNAL_STORAGE / MediaStore).
      await PhotoManager.editor.deleteWithIds([asset.id]);

      final stat = await File(vaultPath).stat();
      final vaultFile = VaultFile(
        id: asset.id,
        originalPath: file.path,
        vaultPath: vaultPath,
        fileName: p.basename(file.path),
        mediaType: asset.type == AssetType.video ? 'video' : 'image',
        sizeBytes: stat.size,
        dateAdded: DateTime.now(),
      );

      // Persist metadata.
      await PreferencesService.addVaultFile(vaultFile.toMap());
      return vaultFile;
    } catch (e) {
      return null;
    }
  }

  /// Move a vault file back into the gallery / public storage.
  static Future<bool> restoreFromVault(VaultFile vaultFile) async {
    try {
      final file = vaultFile.file;
      if (!file.existsSync()) return false;

      // Save to public pictures/movies directory.
      final isVideo = vaultFile.mediaType == 'video';
      final asset = isVideo
          ? await PhotoManager.editor.saveVideo(file, title: vaultFile.fileName)
          : await PhotoManager.editor
              .saveImageWithPath(file.path, title: vaultFile.fileName);

      if (asset == null) return false;

      // Remove vault file and metadata.
      await file.delete();
      await PreferencesService.removeVaultFile(vaultFile.vaultPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a vault file permanently (no restore).
  static Future<bool> deleteFromVault(VaultFile vaultFile) async {
    try {
      final file = vaultFile.file;
      if (file.existsSync()) {
        await file.delete();
      }
      await PreferencesService.removeVaultFile(vaultFile.vaultPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load all vault files from Hive and verify they still exist on disk.
  static List<VaultFile> loadVaultFiles() {
    final maps = PreferencesService.getVaultFiles();
    return maps
        .map(VaultFile.fromMap)
        .where((f) => f.file.existsSync())
        .toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  }
}
