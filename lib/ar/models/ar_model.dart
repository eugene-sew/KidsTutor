import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

/// A class representing a 3D model for AR rendering
class ARModel {
  /// Unique identifier for the model
  final String id;

  /// Display name of the model
  final String name;

  /// Path to the 3D model file
  final String modelPath;

  /// Scale factor for the model
  final double scale;

  /// Rotation of the model
  final Vector3 rotation;

  /// Pronunciation guide for the model name
  final String pronunciation;

  /// Optional fun fact about the model
  final String? funFact;

  /// Shadow intensity (0.0 to 1.0)
  final double shadowIntensity;

  /// Shadow softness (0.0 to 1.0)
  final double shadowSoftness;

  /// Exposure level for lighting (0.0 to 2.0)
  final double exposure;

  /// Environment lighting preset ('neutral', 'sunset', 'night', 'bright')
  final String environmentLighting;

  /// Optional color tint to apply to the model
  final Color? colorTint;

  /// Optional animation to play
  final String? animationName;

  /// Whether the model should auto-rotate
  final bool autoRotate;

  /// Speed of auto-rotation in degrees per second
  final double autoRotateSpeed;

  /// Level of detail setting (0 = low, 1 = medium, 2 = high)
  final int levelOfDetail;

  /// Whether to use compressed textures
  final bool useCompressedTextures;

  /// Maximum texture size (e.g., 512, 1024, 2048)
  final int maxTextureSize;

  /// Constructor
  ARModel({
    required this.id,
    required this.name,
    required this.modelPath,
    this.scale = 1.0,
    Vector3? rotation,
    this.pronunciation = '',
    this.funFact,
    this.shadowIntensity = 0.8,
    this.shadowSoftness = 0.5,
    this.exposure = 1.0,
    this.environmentLighting = 'neutral',
    this.colorTint,
    this.animationName,
    this.autoRotate = false,
    this.autoRotateSpeed = 30.0,
    this.levelOfDetail = 1,
    this.useCompressedTextures = true,
    this.maxTextureSize = 1024,
  }) : rotation = rotation ?? Vector3(0, 0, 0);

  /// Create a copy of this model with modified properties
  ARModel copyWith({
    String? id,
    String? name,
    String? modelPath,
    double? scale,
    Vector3? rotation,
    String? pronunciation,
    String? funFact,
    double? shadowIntensity,
    double? shadowSoftness,
    double? exposure,
    String? environmentLighting,
    Color? colorTint,
    String? animationName,
    bool? autoRotate,
    double? autoRotateSpeed,
    int? levelOfDetail,
    bool? useCompressedTextures,
    int? maxTextureSize,
  }) {
    return ARModel(
      id: id ?? this.id,
      name: name ?? this.name,
      modelPath: modelPath ?? this.modelPath,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      pronunciation: pronunciation ?? this.pronunciation,
      funFact: funFact ?? this.funFact,
      shadowIntensity: shadowIntensity ?? this.shadowIntensity,
      shadowSoftness: shadowSoftness ?? this.shadowSoftness,
      exposure: exposure ?? this.exposure,
      environmentLighting: environmentLighting ?? this.environmentLighting,
      colorTint: colorTint ?? this.colorTint,
      animationName: animationName ?? this.animationName,
      autoRotate: autoRotate ?? this.autoRotate,
      autoRotateSpeed: autoRotateSpeed ?? this.autoRotateSpeed,
      levelOfDetail: levelOfDetail ?? this.levelOfDetail,
      useCompressedTextures:
          useCompressedTextures ?? this.useCompressedTextures,
      maxTextureSize: maxTextureSize ?? this.maxTextureSize,
    );
  }

  /// Get a lower detail version of this model for performance optimization
  ARModel getLowerDetailVersion() {
    if (levelOfDetail <= 0) {
      return this; // Already at lowest detail
    }

    return copyWith(
      levelOfDetail: levelOfDetail - 1,
      shadowIntensity: shadowIntensity * 0.7,
      shadowSoftness: shadowSoftness * 0.5,
      maxTextureSize: levelOfDetail == 2 ? 512 : 256,
    );
  }

  /// Get a higher detail version of this model
  ARModel getHigherDetailVersion() {
    if (levelOfDetail >= 2) {
      return this; // Already at highest detail
    }

    return copyWith(
      levelOfDetail: levelOfDetail + 1,
      shadowIntensity: shadowIntensity * 1.2,
      shadowSoftness: shadowSoftness * 1.5,
      maxTextureSize: levelOfDetail == 0 ? 1024 : 2048,
    );
  }

  /// Get the appropriate model path based on level of detail
  String getOptimizedModelPath() {
    // In a real implementation, you would have different model files for different LODs
    // For this example, we'll just return the original path
    final basePath = modelPath.substring(0, modelPath.lastIndexOf('.'));
    final extension = modelPath.substring(modelPath.lastIndexOf('.'));

    switch (levelOfDetail) {
      case 0:
        return '${basePath}_low$extension';
      case 1:
        return modelPath; // Original model
      case 2:
        return '${basePath}_high$extension';
      default:
        return modelPath;
    }
  }

  /// Get the estimated memory usage of this model in bytes
  int getEstimatedMemoryUsage() {
    // This is a very rough estimate based on texture size and level of detail
    int baseSize = 1024 * 1024; // 1MB base size

    // Adjust for texture size
    baseSize += (maxTextureSize * maxTextureSize * 4) ~/
        1024; // Assuming 4 bytes per pixel

    // Adjust for level of detail
    switch (levelOfDetail) {
      case 0:
        return baseSize ~/ 2; // Low detail uses less memory
      case 1:
        return baseSize; // Medium detail is the base
      case 2:
        return baseSize * 2; // High detail uses more memory
      default:
        return baseSize;
    }
  }
}
