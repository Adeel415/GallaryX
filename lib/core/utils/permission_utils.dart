import 'package:permission_handler/permission_handler.dart';

abstract class PermissionUtils {
  /// Request audio permission (for music on Android 13+).
  static Future<bool> requestAudioPermission() async {
    // Android 13+ uses READ_MEDIA_AUDIO; below uses READ_EXTERNAL_STORAGE.
    PermissionStatus status = await Permission.audio.request();
    if (status.isGranted) return true;

    // Fallback for older Android
    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Open the app settings page so the user can grant permissions manually.
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
