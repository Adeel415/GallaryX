import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/media_service.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_widget.dart';
import '../../vault/providers/vault_provider.dart';
import '../providers/gallery_provider.dart';
import '../widgets/media_grid_widget.dart';
import 'image_viewer_screen.dart';
import '../../video/screens/video_player_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final bool showVideos;
  const GalleryScreen({super.key, this.showVideos = false});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollCtrl = ScrollController();
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  SortMode _sortMode = SortMode.date;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
    _scrollCtrl.addListener(_onScroll);

  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    final granted = await MediaService.requestPermission();

    print("PERMISSION: $granted");

    if (!mounted) return;

    if (granted) {
      ref.read(galleryProvider.notifier).loadAssets(
        filter: widget.showVideos
            ? MediaFilter.videos
            : MediaFilter.images,
        sort: _sortMode,
      );
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(galleryProvider.notifier).loadMore(
            filter: widget.showVideos
                ? MediaFilter.videos
                : MediaFilter.images,
            sort: _sortMode,
          );
    }
  }

  List<AssetEntity> _getAssets(GalleryState state) {
    return state.assets; // NO FILTERING
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selectedIds.contains(asset.id)) {
        _selectedIds.remove(asset.id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(asset.id);
      }
    });
  }

  void _enterSelectMode(AssetEntity asset) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(asset.id);
    });
  }

  Future<void> _moveSelectedToVault(List<AssetEntity> assets) async {
    final selected = assets.where((a) => _selectedIds.contains(a.id)).toList();
    int moved = 0;
    for (final asset in selected) {
      final ok = await ref
          .read(vaultProvider.notifier)
          .addAsset(asset, ref);
      if (ok) moved++;
    }
    if (!mounted) return;
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$moved file(s) moved to vault'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sort by', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...[SortMode.date, SortMode.name, SortMode.size].map((mode) {
            final labels = {
              SortMode.date: ('Date', Icons.calendar_today_outlined),
              SortMode.name: ('Name', Icons.sort_by_alpha_outlined),
              SortMode.size: ('Size', Icons.storage_outlined),
            };
            final (label, icon) = labels[mode]!;
            return ListTile(
              leading: Icon(icon,
                  color: _sortMode == mode ? AppColors.primary : null),
              title: Text(label),
              trailing: _sortMode == mode
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _sortMode = mode);
                Navigator.pop(context);
                ref.read(galleryProvider.notifier).loadAssets(
                      filter: widget.showVideos
                          ? MediaFilter.videos
                          : MediaFilter.images,
                      sort: mode,
                    );
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _openAsset(AssetEntity asset, List<AssetEntity> assets, int index) {
    if (asset.type == AssetType.video) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(asset: asset)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ImageViewerScreen(assets: assets, initialIndex: index),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final permAsync = ref.watch(galleryPermissionProvider);
    final galleryState = ref.watch(galleryProvider);

    return permAsync.when(
      loading: () => const ShimmerGrid(),
      error: (e, _) => EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: e.toString(),
      ),
      data: (granted) {
        if (!granted) {
          return EmptyStateWidget(
            icon: Icons.lock_outline,
            title: AppStrings.permissionTitle,
            subtitle: AppStrings.permissionDesc,
            actionLabel: AppStrings.grantPermission,
            onAction: MediaService.openPermissionSettings,
          );
        }

        if (galleryState.isLoading) return const ShimmerGrid();

        final assets = _getAssets(galleryState);

        if (assets.isEmpty) {
          return EmptyStateWidget(
            icon: widget.showVideos
                ? Icons.videocam_outlined
                : Icons.photo_outlined,
            title: AppStrings.noMedia,
            subtitle: AppStrings.noMediaDesc,
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // ── Toolbar row ─────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${assets.length} ${widget.showVideos ? 'videos' : 'photos'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    if (_selectMode) ...[
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectMode = false;
                            _selectedIds.clear();
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _moveSelectedToVault(assets),
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: Text('Vault (${_selectedIds.length})'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ] else
                      IconButton(
                        onPressed: _openSortSheet,
                        icon: const Icon(Icons.sort_rounded),
                        tooltip: 'Sort',
                      ),
                  ],
                ),
              ),

              // ── Grid ──────────────────────────────────────────────────
              Expanded(
                child: MediaGridWidget(
                  assets: assets,
                  scrollController: _scrollCtrl,
                  selectedIds: _selectedIds,
                  onTap: (asset, index) {
                    if (_selectMode) {
                      _toggleSelect(asset);
                    } else {
                      _openAsset(asset, assets, index);
                    }
                  },
                  onLongPress: _enterSelectMode,
                  footer: galleryState.isLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
