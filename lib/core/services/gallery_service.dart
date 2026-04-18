import 'package:photo_manager/photo_manager.dart';

class GalleryService {

  static Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  static Future<List<AssetEntity>> loadImages() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (albums.isEmpty) return [];

    final album = albums.first;

    final media = await album.getAssetListPaged(
      page: 0,
      size: 1000,
    );

    return media;
  }
}