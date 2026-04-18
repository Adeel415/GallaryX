import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class FileUtils {
  /// Format bytes into human-readable size string.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Format a duration (seconds) as mm:ss or hh:mm:ss.
  static String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${_pad(minutes)}:${_pad(seconds)}';
    }
    return '${_pad(minutes)}:${_pad(seconds)}';
  }

  /// Format [Duration] object.
  static String formatDurationObj(Duration duration) =>
      formatDuration(duration.inSeconds);

  /// Format a [DateTime] with month and year.
  static String formatMonthYear(DateTime dt) =>
      DateFormat.yMMMM().format(dt);

  /// Format a [DateTime] to a readable date-time string.
  static String formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);

  /// Returns the file extension (lowercase, no dot) or empty string.
  static String extension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0) return '';
    return path.substring(idx + 1).toLowerCase();
  }

  /// Build a short label for an AssetEntity.
  static String assetLabel(AssetEntity asset) {
    return asset.title ?? extension(asset.relativePath ?? '') ?? 'File';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
