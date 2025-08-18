import 'dart:async';
import 'package:flutter/services.dart';

import 'capabilities.dart';

class KidverseAR {
  KidverseAR._();
  static const MethodChannel _channel = MethodChannel('kidverse_ar');

  static Future<ArRuntimeCapabilities> queryRuntimeCapabilities() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('queryCapabilities');
    return ArRuntimeCapabilities.fromMap(map ?? const {});
  }
}

