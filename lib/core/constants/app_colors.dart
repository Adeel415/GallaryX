import 'package:flutter/material.dart';

/// Central color palette for Smart Gallery App.
abstract class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryVariant = Color(0xFF4B44CC);
  static const Color secondary = Color(0xFFFF6584);
  static const Color accent = Color(0xFF43E97B);

  // ── Light Theme ──────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // ── Dark Theme ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkDivider = Color(0xFF2D2D4E);
  static const Color darkTextPrimary = Color(0xFFF1F1FF);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // ── Media type badges ────────────────────────────────────────────────────
  static const Color videoBadge = Color(0xFF3B82F6);
  static const Color imageBadge = Color(0xFF10B981);
  static const Color audioBadge = Color(0xFFF59E0B);

  // ── Vault ────────────────────────────────────────────────────────────────
  static const Color vaultGold = Color(0xFFFBBF24);
  static const Color vaultLock = Color(0xFFEF4444);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient musicGradient = LinearGradient(
    colors: [Color(0xFF1DB954), Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
