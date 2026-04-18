// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/preferences_service.dart';

// ── Music services ────────────────────────────────────────────────────────────
import 'features/music/services/audio_handler.dart';
import 'features/music/services/song_repository.dart';

import 'features/home/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive local storage ────────────────────────────────────────────────────
  await Hive.initFlutter();

  // ── App preferences (PIN, theme, favourites) ──────────────────────────────
  await PreferencesService.init();

  // ── Song library (file_picker + Hive) ─────────────────────────────────────
  // Opens the Hive box that stores song paths between sessions.
  await SongRepository.init();

  // ── audio_service: MUST be called before runApp() ─────────────────────────
  // Registers the foreground service on Android and sets [audioHandler].
 // await initAudioService();

  // ── System UI chrome ──────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Allow all orientations (video player needs landscape).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    const ProviderScope(
      child: SmartGalleryApp(),
    ),
  );
}

class SmartGalleryApp extends ConsumerWidget {
  const SmartGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}