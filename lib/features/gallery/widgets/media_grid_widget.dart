import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:photo_manager/photo_manager.dart';
import 'media_thumbnail_widget.dart';

class MediaGridWidget extends StatelessWidget {
  final List<AssetEntity> assets;
  final int crossAxisCount;
  final void Function(AssetEntity asset, int index)? onTap;
  final void Function(AssetEntity asset)? onLongPress;
  final Set<String> selectedIds;
  final ScrollController? scrollController;
  final Widget? footer;

  const MediaGridWidget({
    super.key,
    required this.assets,
    this.crossAxisCount = 3,
    this.onTap,
    this.onLongPress,
    this.selectedIds = const {},
    this.scrollController,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: assets.length + (footer != null ? 1 : 0),
        itemBuilder: (context, index) {
          // Footer cell (loading indicator or end-of-list).
          if (footer != null && index == assets.length) {
            return SizedBox(height: 60, child: footer);
          }

          final asset = assets[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: crossAxisCount,
            duration: const Duration(milliseconds: 300),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: MediaThumbnailWidget(
                  asset: asset,
                  selected: selectedIds.contains(asset.id),
                  onTap: () => onTap?.call(asset, index),
                  onLongPress: () => onLongPress?.call(asset),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
