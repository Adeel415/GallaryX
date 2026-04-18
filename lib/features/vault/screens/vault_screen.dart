import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/vault_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../widgets/empty_state_widget.dart';
import '../providers/vault_provider.dart';
import 'vault_lock_screen.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _checkAccess() {
    final unlocked = ref.read(vaultUnlockedProvider);
    final setup = ref.read(vaultSetupProvider);
    if (!unlocked || !setup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VaultLockScreen()),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _confirmDelete(VaultFile f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text('${f.fileName} will be deleted and cannot be recovered.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success =
          await ref.read(vaultProvider.notifier).delete(f);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'File deleted' : 'Could not delete file'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restore(VaultFile f) async {
    final success =
        await ref.read(vaultProvider.notifier).restore(f);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${f.fileName} restored to gallery'
              : 'Could not restore file'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final unlocked = ref.watch(vaultUnlockedProvider);
    final files = ref.watch(vaultProvider);

    if (!unlocked) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded,
                size: 64, color: AppColors.vaultGold),
            const SizedBox(height: 16),
            const Text('Vault is Locked'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VaultLockScreen()),
              ),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock Vault'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.vaultGold,
                  foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    if (files.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.lock_open_outlined,
        title: AppStrings.vaultEmpty,
        subtitle: AppStrings.vaultEmptyDesc,
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: files.length,
        itemBuilder: (ctx, i) {
          final f = files[i];
          return AnimationConfiguration.staggeredGrid(
            position: i,
            columnCount: 3,
            duration: const Duration(milliseconds: 300),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _VaultThumbnail(
                  file: f,
                  onRestore: () => _restore(f),
                  onDelete: () => _confirmDelete(f),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Vault Thumbnail Cell ──────────────────────────────────────────────────────
class _VaultThumbnail extends StatelessWidget {
  final VaultFile file;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _VaultThumbnail({
    required this.file,
    required this.onRestore,
    required this.onDelete,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
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
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(file.fileName),
              subtitle: Text(
                '${FileUtils.formatSize(file.sizeBytes)}  ·  '
                '${FileUtils.formatDateTime(file.dateAdded)}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline,
                  color: AppColors.primary),
              title: const Text(AppStrings.restoreFromVault),
              onTap: () {
                Navigator.pop(context);
                onRestore();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red),
              title: const Text('Delete Permanently',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultFile = File(file.vaultPath);
    final exists = vaultFile.existsSync();

    return GestureDetector(
      onTap: () => _showOptions(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Thumbnail ───────────────────────────────────────────────
          if (exists && file.mediaType == 'image')
            Image.file(vaultFile, fit: BoxFit.cover)
          else
            Container(
              color: const Color(0xFF1E1E35),
              child: Icon(
                file.mediaType == 'video'
                    ? Icons.videocam_rounded
                    : Icons.image_rounded,
                color: Colors.white54,
                size: 36,
              ),
            ),

          // ── Lock badge ─────────────────────────────────────────────
          const Positioned(
            top: 4,
            left: 4,
            child: Icon(Icons.lock_rounded,
                color: AppColors.vaultGold, size: 16),
          ),

          // ── Video badge ────────────────────────────────────────────
          if (file.mediaType == 'video')
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white70, size: 22),
            ),
        ],
      ),
    );
  }
}
