import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

enum SortMode { date, size, name }

enum MediaFilter { all, images, videos }

class MediaService {
  // ─────────────────────────────────────────────
  // PERMISSION
  // ─────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    final PermissionState state =
    await PhotoManager.requestPermissionExtend();

    return state.isAuth || state.isLimited;
  }

  static Future<void> openPermissionSettings() async {
    await PhotoManager.openSetting();
  }

  // ─────────────────────────────────────────────
  // LOAD MEDIA (FIXED VERSION)
  // ─────────────────────────────────────────────
  static Future<List<AssetEntity>> loadAllAssets({
    MediaFilter filter = MediaFilter.all,
    SortMode sort = SortMode.date,
    int page = 0,
    int pageSize = 1000,
  }) async {

    RequestType type;

    switch (filter) {
      case MediaFilter.images:
        type = RequestType.image;
        break;

      case MediaFilter.videos:
        type = RequestType.video;
        break;

      case MediaFilter.all:
      default:
        type = RequestType.common;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: true,
    );

    if (albums.isEmpty) return [];

    final album = albums.first;

    final assets = await album.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    return _sortAssets(assets, sort);
  }

  // ─────────────────────────────────────────────
  // COUNT (FIXED)
  // ─────────────────────────────────────────────
  static Future<int> loadAssetCount({
    MediaFilter filter = MediaFilter.all,
  }) async {
    RequestType type;

    switch (filter) {
      case MediaFilter.images:
        type = RequestType.image;
        break;
      case MediaFilter.videos:
        type = RequestType.video;
        break;
      case MediaFilter.all:
      default:
        type = RequestType.common;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: false,
    );

    if (albums.isEmpty) return 0;

    int total = 0;

    for (final album in albums) {
      total += await album.assetCountAsync;
    }

    return total;
  }

  // ─────────────────────────────────────────────
  // THUMBNAIL
  // ─────────────────────────────────────────────
  static Future<Uint8List?> getThumbnail(
      AssetEntity asset, {
        int width = 200,
        int height = 200,
      }) async {
    return asset.thumbnailDataWithSize(
      ThumbnailSize(width, height),
    );
  }

  // ─────────────────────────────────────────────
  // SORTING
  // ─────────────────────────────────────────────
  static List<AssetEntity> _sortAssets(
      List<AssetEntity> assets,
      SortMode sort,
      ) {
    switch (sort) {
      case SortMode.date:
        assets.sort(
              (a, b) => b.createDateTime.compareTo(a.createDateTime),
        );
        break;

      case SortMode.size:
        assets.sort(
              (a, b) => (b.size.width * b.size.height)
              .compareTo(a.size.width * a.size.height),
        );
        break;

      case SortMode.name:
        assets.sort(
              (a, b) => (a.title ?? '').compareTo(b.title ?? ''),
        );
        break;
    }
    return assets;
  }
}