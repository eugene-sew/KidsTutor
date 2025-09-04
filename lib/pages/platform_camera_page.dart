import 'package:flutter/material.dart';
import 'dart:io';
import 'ar_explore_page.dart';
import 'android_camera_page.dart';

class PlatformCameraPage extends StatelessWidget {
  const PlatformCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return const ARExplorePage();
    } else {
      return const AndroidCameraPage();
    }
  }
}
