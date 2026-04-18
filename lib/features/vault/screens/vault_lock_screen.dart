import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/preferences_service.dart';
import '../providers/vault_provider.dart';

enum _LockMode { verify, setup, confirmSetup }

class VaultLockScreen extends ConsumerStatefulWidget {
  const VaultLockScreen({super.key});

  @override
  ConsumerState<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends ConsumerState<VaultLockScreen>
    with SingleTickerProviderStateMixin {
  _LockMode _mode = _LockMode.verify;
  String _pin = '';
  String _firstPin = '';
  String _error = '';
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _mode = PreferencesService.isVaultSetUp
        ? _LockMode.verify
        : _LockMode.setup;

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (_mode) {
      case _LockMode.verify:
        return AppStrings.vaultLockTitle;
      case _LockMode.setup:
        return 'Create Vault PIN';
      case _LockMode.confirmSetup:
        return 'Confirm Your PIN';
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = '';
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 120), _onPinComplete);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onPinComplete() async {
    switch (_mode) {
      case _LockMode.verify:
        if (PreferencesService.verifyVaultPin(_pin)) {
          HapticFeedback.mediumImpact();
          ref.read(vaultUnlockedProvider.notifier).state = true;
          Navigator.pop(context);
        } else {
          _shake('Wrong PIN. Try again.');
        }
        break;

      case _LockMode.setup:
        _firstPin = _pin;
        setState(() { _pin = ''; _mode = _LockMode.confirmSetup; });
        break;

      case _LockMode.confirmSetup:
        if (_pin == _firstPin) {
          await PreferencesService.setVaultPin(_pin);
          HapticFeedback.mediumImpact();
          ref.read(vaultSetupProvider.notifier).state = true;
          ref.read(vaultUnlockedProvider.notifier).state = true;
          Navigator.pop(context);
        } else {
          _shake(AppStrings.pinMismatch);
          setState(() { _mode = _LockMode.setup; _firstPin = ''; });
        }
        break;
    }
  }

  void _shake(String msg) {
    HapticFeedback.vibrate();
    setState(() { _pin = ''; _error = msg; });
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            const SizedBox(height: 40),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.vaultGold,
                    AppColors.vaultGold.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.vaultGold.withOpacity(0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              _title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == _LockMode.verify
                  ? AppStrings.enterPin
                  : _mode == _LockMode.confirmSetup
                      ? 'Re-enter your PIN to confirm'
                      : AppStrings.vaultSetupDesc,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // ── PIN dots ────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  _shakeCtrl.isAnimating
                      ? (_shakeCtrl.value % 2 == 0 ? _shakeAnim.value : -_shakeAnim.value)
                      : 0,
                  0,
                ),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 18 : 16,
                    height: filled ? 18 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Error text ──────────────────────────────────────────────
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: _error.isNotEmpty ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                _error,
                style: const TextStyle(
                    color: AppColors.vaultLock,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),

            const Spacer(),

            // ── Numpad ──────────────────────────────────────────────────
            _Numpad(onDigit: _onDigit, onDelete: _onDelete),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Number Pad ────────────────────────────────────────────────────────────────
class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _Numpad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: rows.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) => _NumKey(
              label: key,
              onPressed: () {
                if (key == '<') {
                  onDelete();
                } else if (key.isNotEmpty) {
                  onDigit(key);
                }
              },
            )).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NumKey({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(width: 70, height: 70);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withOpacity(0.08),
        ),
        child: Center(
          child: label == '<'
              ? const Icon(Icons.backspace_outlined,
                  color: AppColors.primary, size: 24)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
        ),
      ),
    );
  }
}
