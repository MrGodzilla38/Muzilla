import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/muzilla_audio_handler.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    audioServiceHandler = await AudioService.init(
      builder: MuzillaAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.muzilla.channel.audio',
        androidNotificationChannelName: 'Müzik çalma',
        androidNotificationIcon: 'drawable/ic_stat_music_note',
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    );
  } catch (error) {
    debugPrint('Muzilla: audio_service başlatılamadı: $error');
  }
  runApp(const ProviderScope(child: MuzillaApp()));
}

class MuzillaApp extends StatelessWidget {
  const MuzillaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muzilla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
