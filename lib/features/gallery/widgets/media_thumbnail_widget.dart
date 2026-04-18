import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/media_service.dart';
import '../../../core/utils/file_utils.dart';

class MediaThumbnailWidget extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const MediaThumbnailWidget({
    super.key,
    required this.asset,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  State<MediaThumbnailWidget> createState() => _MediaThumbnailWidgetState();
}

class _MediaThumbnailWidgetState extends State<MediaThumbnailWidget> {
  Uint8List? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final bytes = await MediaService.getThumbnail(
      widget.asset,
      width: 200,
      height: 200,
    );
    if (mounted) {
      setState(() {
        _thumbnail = bytes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: widget.selected
              ? Border.all(color: AppColors.primary, width: 3)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            if (_loading)
              Container(color: Colors.grey.shade300)
            else if (_thumbnail != null)
              Image.memory(
                _thumbnail!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              Container(
                color: Colors.grey.shade400,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.white54),
              ),

            // ── Video overlay ─────────────────────────────────────────────
            if (isVideo) ...[
              // Dark gradient at the bottom
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.darkOverlay,
                  ),
                ),
              ),
              // Play icon
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 32,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              // Duration badge
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    FileUtils.formatDuration(widget.asset.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // ── Selection indicator ───────────────────────────────────────
            if (widget.selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
