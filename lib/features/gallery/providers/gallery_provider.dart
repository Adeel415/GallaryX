import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/services/media_service.dart';

// ── Sort Mode ─────────────────────────────────────────────────────────────────
final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.date);

// ── Media Filter ──────────────────────────────────────────────────────────────
final mediaFilterProvider =
    StateProvider<MediaFilter>((ref) => MediaFilter.all);

// ── Permission ────────────────────────────────────────────────────────────────
final galleryPermissionProvider = FutureProvider<bool>((ref) async {
  return MediaService.requestPermission();
});

// ── Gallery Assets ────────────────────────────────────────────────────────────
class GalleryNotifier extends StateNotifier<GalleryState> {
  GalleryNotifier() : super(GalleryState.initial());

  /// Load first page of media.
  Future<void> loadAssets({
    MediaFilter filter = MediaFilter.all,
    SortMode sort = SortMode.date,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final assets = await MediaService.loadAllAssets(
        filter: filter,
        sort: sort,
        page: 0,
        pageSize: 80,
      );
      state = state.copyWith(
        assets: assets,
        isLoading: false,
        currentPage: 0,
        hasMore: assets.length == 80,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load the next page (infinite scroll).
  Future<void> loadMore({
    MediaFilter filter = MediaFilter.all,
    SortMode sort = SortMode.date,
  }) async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;
    try {
      final more = await MediaService.loadAllAssets(
        filter: filter,
        sort: sort,
        page: nextPage,
        pageSize: 80,
      );
      state = state.copyWith(
        assets: [...state.assets, ...more],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: more.length == 80,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Remove an asset from the current list (e.g., after moving to vault).
  void removeAsset(String assetId) {
    state = state.copyWith(
      assets: state.assets.where((a) => a.id != assetId).toList(),
    );
  }

  void refresh() => loadAssets();
}

// ── State Model ───────────────────────────────────────────────────────────────
class GalleryState {
  final List<AssetEntity> assets;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? errorMessage;

  const GalleryState({
    required this.assets,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.currentPage,
    this.errorMessage,
  });

  factory GalleryState.initial() => const GalleryState(
        assets: [],
        isLoading: false,
        isLoadingMore: false,
        hasMore: true,
        currentPage: 0,
      );

  GalleryState copyWith({
    List<AssetEntity>? assets,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? errorMessage,
  }) =>
      GalleryState(
        assets: assets ?? this.assets,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Providers ────────────────────────────────────────────────────────────────
final galleryProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>(
  (ref) => GalleryNotifier(),
);

/// Image-only assets.
final imageAssetsProvider = Provider<List<AssetEntity>>((ref) {
  final all = ref.watch(galleryProvider).assets;
  return all.where((a) => a.type == AssetType.image).toList();
});

/// Video-only assets.
final videoAssetsProvider = Provider<List<AssetEntity>>((ref) {
  final all = ref.watch(galleryProvider).assets;
  return all.where((a) => a.type == AssetType.video).toList();
});
