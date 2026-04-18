import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/services/vault_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../gallery/providers/gallery_provider.dart';

// ── Vault Setup State ─────────────────────────────────────────────────────────
final vaultSetupProvider = StateProvider<bool>(
  (ref) => PreferencesService.isVaultSetUp,
);

// ── Vault Locked / Unlocked ───────────────────────────────────────────────────
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);

// ── Vault Files Notifier ──────────────────────────────────────────────────────
class VaultNotifier extends StateNotifier<List<VaultFile>> {
  VaultNotifier() : super([]);

  void load() {
    state = VaultService.loadVaultFiles();
  }

  Future<bool> addAsset(AssetEntity asset, WidgetRef ref) async {
    final vaultFile = await VaultService.moveToVault(asset);
    if (vaultFile == null) return false;

    state = [vaultFile, ...state];

    // Remove from gallery cache.
    ref.read(galleryProvider.notifier).removeAsset(asset.id);
    return true;
  }

  Future<bool> restore(VaultFile vaultFile) async {
    final ok = await VaultService.restoreFromVault(vaultFile);
    if (!ok) return false;

    state = state.where((f) => f.vaultPath != vaultFile.vaultPath).toList();
    return true;
  }

  Future<bool> delete(VaultFile vaultFile) async {
    final ok = await VaultService.deleteFromVault(vaultFile);
    if (!ok) return false;

    state = state.where((f) => f.vaultPath != vaultFile.vaultPath).toList();
    return true;
  }
}

final vaultProvider =
    StateNotifierProvider<VaultNotifier, List<VaultFile>>(
  (ref) => VaultNotifier()..load(),
);
