import 'dart:async';
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'ar/utils/settings_service.dart';
import 'utils/tts_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings (keep before runApp)
  final settings = SettingsService();
  await settings.initialize();

  runApp(const MyApp());

  // Defer TTS initialization to avoid slowing first frame
  scheduleMicrotask(() {
    TtsService().initialize();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Tutor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
