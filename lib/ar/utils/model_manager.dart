import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart';
import 'ar_manager.dart';
import 'ar_error_handler.dart';
import 'model_optimizer.dart';
import 'resource_manager.dart';
import '../models/ar_model.dart';

/// A singleton manager class for 3D model loading and caching
class ModelManager {
  // Singleton instance
  static final ModelManager _instance = ModelManager._internal();

  // Factory constructor to return the singleton instance
  factory ModelManager() => _instance;

  // Private constructor
  ModelManager._internal();

  // Model cache
  final Map<String, ARNode> _modelCache = {};
  final Map<String, String> _modelPathCache = {};

  // Cache usage tracking
  final Map<String, int> _modelLastAccessTime = {};
  final Map<String, int> _modelAccessCount = {};

  // Cache size limits
  static const int _maxCacheSize = 10;
  static const int _trimCacheSize = 5;

  // Memory usage tracking
  int _estimatedMemoryUsageBytes = 0;
  static const int _estimatedModelSizeBytes =
      5 * 1024 * 1024; // 5MB per model estimate

  // Common model names for preloading
  final List<String> _commonModels = [
    'apple',
    'ball',
    'cat',
    'dog',
    'elephant',
  ];

  // Error handler
  final ARErrorHandler _errorHandler = ARErrorHandler();

  // Getters for cache metrics
  int get cacheSize => _modelCache.length;
  int get estimatedMemoryUsageBytes => _estimatedMemoryUsageBytes;
  int get getCacheSize => _modelCache.length;

  /// Get a model node by name, loading it if necessary, with enhanced rendering properties and optimization
  Future<ARNode?> getModel(
    String modelName, {
    double scale = 1.0,
    Vector3? position,
    Vector3? rotation,
    double shadowIntensity = 0.8,
    double shadowSoftness = 0.5,
    double exposure = 1.0,
    String environmentLighting = 'neutral',
    Color? colorTint,
    String? animationName,
    bool autoRotate = false,
    double autoRotateSpeed = 30.0,
    int? levelOfDetail,
    bool? useCompressedTextures,
    int? maxTextureSize,
  }) async {
    // Update access time and count for this model
    final now = DateTime.now().millisecondsSinceEpoch;
    _modelLastAccessTime[modelName] = now;
    _modelAccessCount[modelName] = (_modelAccessCount[modelName] ?? 0) + 1;

    // Determine appropriate detail level if not specified
    final resourceManager = ResourceManager();
    final modelOptimizer = ModelOptimizer();
    final effectiveLOD =
        levelOfDetail ?? modelOptimizer.getAppropriateDetailLevel();
    final effectiveUseCompressedTextures =
        useCompressedTextures ?? resourceManager.isPerformanceDegraded;
    final effectiveMaxTextureSize =
        maxTextureSize ?? (resourceManager.isPerformanceDegraded ? 512 : 1024);

    // Create cache key that includes optimization parameters
    final cacheKey =
        '${modelName}_lod${effectiveLOD}_${effectiveUseCompressedTextures ? 'compressed' : 'uncompressed'}_$effectiveMaxTextureSize';

    // Check if optimized model is already in cache
    if (_modelCache.containsKey(cacheKey)) {
      // Return a copy of the cached node with the requested properties
      final cachedNode = _modelCache[cacheKey]!;
      return cachedNode.copyWith(
        scale: Vector3(scale, scale, scale),
        position: position,
        rotation: rotation,
        shadowIntensity: shadowIntensity,
        shadowSoftness: shadowSoftness,
        exposure: exposure,
        environmentLighting: environmentLighting,
        colorTint: colorTint,
        animationName: animationName,
        autoRotate: autoRotate,
        autoRotateSpeed: autoRotateSpeed,
      );
    }

    // Check if we need to trim the cache before loading a new model
    if (_modelCache.length >= _maxCacheSize) {
      await trimCache();
    }

    // Load the model with appropriate optimization
    try {
      // Create a temporary AR model to pass to the optimizer
      final tempModel = ARModel(
        id: modelName,
        name: modelName,
        modelPath: 'assets/3d_models/$modelName.glb',
        levelOfDetail: effectiveLOD,
        useCompressedTextures: effectiveUseCompressedTextures,
        maxTextureSize: effectiveMaxTextureSize,
      );

      // Get optimized model path
      final modelPath = await modelOptimizer.getOptimizedModelPath(tempModel);
      if (modelPath.isEmpty) {
        debugPrint('Model not found: $modelName');
        return null;
      }

      // Apply texture compression if needed
      if (effectiveUseCompressedTextures) {
        await modelOptimizer.applyTextureCompression(tempModel);
      }

      // Create the node with optimized properties
      final node = ARNode(
        id: cacheKey,
        modelPath: modelPath,
        scale: Vector3(scale, scale, scale),
        position: position ?? Vector3(0, 0, 0),
        rotation: rotation ?? Vector3(0, 0, 0),
        shadowIntensity: shadowIntensity * (effectiveLOD == 0 ? 0.7 : 1.0),
        shadowSoftness: shadowSoftness * (effectiveLOD == 0 ? 0.5 : 1.0),
        exposure: exposure,
        environmentLighting: environmentLighting,
        colorTint: colorTint,
        animationName: animationName,
        autoRotate: autoRotate,
        autoRotateSpeed: autoRotateSpeed,
      );

      // Cache the node with optimization parameters
      _modelCache[cacheKey] = node;
      _updateMemoryUsage(cacheKey, true);
      debugPrint(
          'Loaded and cached optimized model: $cacheKey (LOD: $effectiveLOD)');
      return node;
    } catch (e) {
      await _errorHandler.handleException(
        e is Exception ? e : Exception(e.toString()),
        type: ARErrorType.modelLoading,
        customMessage: 'Failed to load optimized model: $modelName',
        context: {
          'modelName': modelName,
          'levelOfDetail': effectiveLOD,
          'useCompressedTextures': effectiveUseCompressedTextures,
          'maxTextureSize': effectiveMaxTextureSize,
          'cacheSize': _modelCache.length,
        },
        showUserFeedback: false,
      );

      // Fall back to standard loading if optimization fails
      return _loadStandardModel(
        modelName,
        scale: scale,
        position: position,
        rotation: rotation,
        shadowIntensity: shadowIntensity,
        shadowSoftness: shadowSoftness,
        exposure: exposure,
        environmentLighting: environmentLighting,
        colorTint: colorTint,
        animationName: animationName,
        autoRotate: autoRotate,
        autoRotateSpeed: autoRotateSpeed,
      );
    }
  }

  /// Load a model without optimization (fallback method)
  Future<ARNode?> _loadStandardModel(
    String modelName, {
    double scale = 1.0,
    Vector3? position,
    Vector3? rotation,
    double shadowIntensity = 0.8,
    double shadowSoftness = 0.5,
    double exposure = 1.0,
    String environmentLighting = 'neutral',
    Color? colorTint,
    String? animationName,
    bool autoRotate = false,
    double autoRotateSpeed = 30.0,
  }) async {
    try {
      final modelPath = await _getModelPath(modelName);
      if (modelPath == null) {
        debugPrint('Model not found: $modelName');
        return null;
      }

      final node = ARNode(
        id: modelName,
        modelPath: modelPath,
        scale: Vector3(scale, scale, scale),
        position: position ?? Vector3(0, 0, 0),
        rotation: rotation ?? Vector3(0, 0, 0),
        shadowIntensity: shadowIntensity,
        shadowSoftness: shadowSoftness,
        exposure: exposure,
        environmentLighting: environmentLighting,
        colorTint: colorTint,
        animationName: animationName,
        autoRotate: autoRotate,
        autoRotateSpeed: autoRotateSpeed,
      );

      // Cache the node with default properties
      _modelCache[modelName] = node;
      _updateMemoryUsage(modelName, true);
      debugPrint('Loaded and cached standard model: $modelName (fallback)');
      return node;
    } catch (e) {
      await _errorHandler.handleException(
        e is Exception ? e : Exception(e.toString()),
        type: ARErrorType.modelLoading,
        customMessage: 'Failed to load standard model: $modelName',
        context: {
          'modelName': modelName,
          'fallbackMode': true,
          'cacheSize': _modelCache.length,
        },
        showUserFeedback: false,
      );
      return null;
    }
  }

  /// Get the file path for a model
  Future<String?> _getModelPath(String modelName) async {
    // Check if path is already cached
    if (_modelPathCache.containsKey(modelName)) {
      return _modelPathCache[modelName];
    }

    try {
      // Check if model exists in assets
      final modelAssetPath = 'assets/3d_models/$modelName.glb';

      // For AR Flutter Plugin, we need to copy the asset to a file
      final bytes = await rootBundle.load(modelAssetPath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$modelName.glb');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      // Cache the path
      final filePath = file.path;
      _modelPathCache[modelName] = filePath;
      return filePath;
    } catch (e) {
      // Try alternative extension
      try {
        final modelAssetPath = 'assets/3d_models/$modelName.gltf';

        final bytes = await rootBundle.load(modelAssetPath);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$modelName.gltf');
        await file.writeAsBytes(bytes.buffer.asUint8List());

        final filePath = file.path;
        _modelPathCache[modelName] = filePath;
        return filePath;
      } catch (e) {
        debugPrint('Model file not found for $modelName: $e');
        return null;
      }
    }
  }

  /// Preload common models to improve performance
  Future<void> preloadCommonModels() async {
    for (final modelName in _commonModels) {
      try {
        await _getModelPath(modelName);
        debugPrint('Preloaded model: $modelName');
      } catch (e) {
        await _errorHandler.handleException(
          e is Exception ? e : Exception(e.toString()),
          type: ARErrorType.modelLoading,
          customMessage: 'Failed to preload model: $modelName',
          context: {
            'modelName': modelName,
            'preloadMode': true,
          },
          showUserFeedback: false,
        );
      }
    }
  }

  /// Clear the model cache
  void clearCache() {
    _modelCache.clear();
    _estimatedMemoryUsageBytes = 0;
    debugPrint('Model cache cleared');
  }

  /// Trim the cache by removing least recently used models
  Future<void> trimCache() async {
    if (_modelCache.length <= _trimCacheSize) {
      return; // Cache is already small enough
    }

    debugPrint(
        'Trimming model cache from ${_modelCache.length} to $_trimCacheSize models');

    // Sort models by last access time
    final sortedModels = _modelLastAccessTime.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Keep track of how many models we've removed
    int removedCount = 0;

    // Remove oldest models until we reach the target size
    for (final entry in sortedModels) {
      final modelName = entry.key;

      // Don't remove common models that are frequently used
      if (_commonModels.contains(modelName)) {
        continue;
      }

      // Don't remove if it's not in the cache
      if (!_modelCache.containsKey(modelName)) {
        continue;
      }

      // Remove from cache
      _modelCache.remove(modelName);
      _estimatedMemoryUsageBytes -= _estimatedModelSizeBytes;

      debugPrint('Removed model from cache: $modelName');
      removedCount++;

      // Stop if we've removed enough models
      if (_modelCache.length <= _trimCacheSize) {
        break;
      }
    }

    debugPrint(
        'Trimmed cache: removed $removedCount models, new size: ${_modelCache.length}');
  }

  /// Update the estimated memory usage when adding a model to cache
  void _updateMemoryUsage(String modelName, bool isAdding) {
    if (isAdding) {
      _estimatedMemoryUsageBytes += _estimatedModelSizeBytes;
    } else {
      _estimatedMemoryUsageBytes -= _estimatedModelSizeBytes;
    }

    debugPrint(
        'Estimated memory usage: ${(_estimatedMemoryUsageBytes / 1024 / 1024).toStringAsFixed(1)} MB');
  }

  /// Check if a model exists
  Future<bool> modelExists(String modelName) async {
    try {
      final modelPath = await _getModelPath(modelName);
      return modelPath != null;
    } catch (e) {
      return false;
    }
  }

  /// Get models with optimized level of detail based on current performance
  Future<ARNode?> getOptimizedModel(String modelName, ARModel model) async {
    final resourceManager = ResourceManager();
    final modelOptimizer = ModelOptimizer();

    // Determine appropriate LOD based on performance
    int lod = modelOptimizer.getAppropriateDetailLevel();

    // Get the model with appropriate LOD
    return getModel(
      modelName,
      scale: model.scale,
      rotation: model.rotation,
      shadowIntensity: model.shadowIntensity,
      shadowSoftness: model.shadowSoftness,
      exposure: model.exposure,
      environmentLighting: model.environmentLighting,
      colorTint: model.colorTint,
      animationName: model.animationName,
      autoRotate: model.autoRotate,
      autoRotateSpeed: model.autoRotateSpeed,
      levelOfDetail: lod,
      useCompressedTextures: resourceManager.isPerformanceDegraded,
      maxTextureSize: resourceManager.isPerformanceDegraded ? 512 : 1024,
    );
  }
}
