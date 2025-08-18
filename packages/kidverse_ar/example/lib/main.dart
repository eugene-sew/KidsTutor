import 'package:flutter/material.dart';
import 'package:kidverse_ar/kidverse_ar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ArRuntimeCapabilities? caps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await KidverseAR.queryRuntimeCapabilities();
    setState(() => caps = c);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Kidverse AR Capabilities')),
        body: Center(
          child: caps == null
              ? const CircularProgressIndicator()
              : Text(caps!.toMap().toString()),
        ),
      ),
    );
  }
}

