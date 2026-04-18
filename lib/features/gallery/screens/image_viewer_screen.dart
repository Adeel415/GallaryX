import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/file_utils.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late int _currentIndex;
  bool _uiVisible = true;
  bool _isFavorite = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _loadFavorite();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _loadFavorite() {
    setState(() {
      _isFavorite = PreferencesService.isFavorite(
          widget.assets[_currentIndex].id);
    });
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  Future<void> _toggleFavorite() async {
    final asset = widget.assets[_currentIndex];
    await PreferencesService.toggleFavorite(asset.id);
    setState(() => _isFavorite = PreferencesService.isFavorite(asset.id));
  }

  Future<void> _showInfoSheet() async {
    final asset = widget.assets[_currentIndex];
    final file = await asset.file;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InfoSheet(asset: asset, file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Page View ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggleUI,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.assets.length,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
                _loadFavorite();
              },
              itemBuilder: (ctx, idx) {
                return _ImagePage(asset: widget.assets[idx]);
              },
            ),
          ),

          // ── Top Bar ────────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          '${_currentIndex + 1} / ${widget.assets.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFavorite
                                ? AppColors.secondary
                                : Colors.white,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded,
                              color: Colors.white),
                          onPressed: _showInfoSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single image page with InteractiveViewer ──────────────────────────────────
class _ImagePage extends StatefulWidget {
  final AssetEntity asset;
  const _ImagePage({required this.asset});

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  File? _file;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await widget.asset.file;
    if (mounted) setState(() { _file = f; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    if (_file == null) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
      );
    }
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: Hero(
        tag: widget.asset.id,
        child: Image.file(_file!, fit: BoxFit.contain),
      ),
    );
  }
}

// ── Info Bottom Sheet ─────────────────────────────────────────────────────────
class _InfoSheet extends StatelessWidget {
  final AssetEntity asset;
  final File? file;

  const _InfoSheet({required this.asset, this.file});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1A1A2E)
        : Colors.white;

    int sizeBytes = 0;
    if (file != null) sizeBytes = file!.lengthSync();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('File Info',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _infoRow(context, Icons.photo_outlined, 'Name',
              asset.title ?? 'Unknown'),
          _infoRow(context, Icons.calendar_today_outlined, 'Date',
              FileUtils.formatDateTime(asset.createDateTime)),
          _infoRow(context, Icons.aspect_ratio_outlined, 'Dimensions',
              '${asset.width} × ${asset.height}'),
          _infoRow(context, Icons.storage_outlined, 'Size',
              sizeBytes > 0 ? FileUtils.formatSize(sizeBytes) : 'Unknown'),
          if (asset.type == AssetType.video)
            _infoRow(context, Icons.timer_outlined, 'Duration',
                FileUtils.formatDuration(asset.duration)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext ctx, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: Theme.of(ctx).textTheme.bodyMedium),
          const Spacer(),
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
