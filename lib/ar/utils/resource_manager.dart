import 'dart:async';
import 'package:flutter/material.dart';
import 'ar_manager.dart';
import 'model_manager.dart';
import 'settings_service.dart';
import 'thermal_manager.dart';

/// A singleton manager class for AR resource management
class ResourceManager {
  // Singleton instance
  static final ResourceManager _instance = ResourceManager._internal();

  // Factory constructor to return the singleton instance
  factory ResourceManager() => _instance;

  // Private constructor
  ResourceManager._internal();

  // Managers
  final ARManager _arManager = ARManager();
  final ModelManager _modelManager = ModelManager();
  final SettingsService _settingsService = SettingsService();
  final ThermalManager _thermalManager = ThermalManager();

  // Resource monitoring
  bool _isMonitoringResources = false;
  Timer? _resourceMonitoringTimer;

  // App state
  bool _isInForeground = true;

  // Memory usage thresholds (in MB)
  static const double _highMemoryUsageThreshold = 200.0; // MB
  static const double _criticalMemoryUsageThreshold = 300.0; // MB

  // Performance metrics
  double _estimatedMemoryUsage = 0.0; // MB
  int _activeModelsCount = 0;
  int _cachedModelsCount = 0;
  bool _isPerformanceDegraded = false;
  bool _isThermallyDegraded = false;

  // Getters for metrics
  double get estimatedMemoryUsage => _estimatedMemoryUsage;
  int get activeModelsCount => _activeModelsCount;
  int get cachedModelsCount => _cachedModelsCount;
  bool get isPerformanceDegraded =>
      _isPerformanceDegraded || _isThermallyDegraded;
  bool get isInForeground => _isInForeground;
  ThermalManager get thermalManager => _thermalManager;

  /// Initialize the resource manager
  Future<void> initialize() async {
    // Ensure settings service is initialized
    if (!_settingsService.isInitialized) {
      await _settingsService.initialize();
    }

    // Initialize thermal manager
    await _thermalManager.initialize();

    // Start resource monitoring
    _startResourceMonitoring();

    // Register app lifecycle listeners
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

    debugPrint('ResourceManager initialized');
  }

  /// Start monitoring resource usage
  void _startResourceMonitoring() {
    if (_isMonitoringResources) return;

    _isMonitoringResources = true;
    _resourceMonitoringTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _monitorResources(),
    );

    debugPrint('Resource monitoring started');
  }

  /// Stop monitoring resource usage
  void _stopResourceMonitoring() {
    if (!_isMonitoringResources) return;

    _resourceMonitoringTimer?.cancel();
    _resourceMonitoringTimer = null;
    _isMonitoringResources = false;

    debugPrint('Resource monitoring stopped');
  }

  /// Monitor resource usage and take action if necessary
  Future<void> _monitorResources() async {
    try {
      // Update metrics
      _updateResourceMetrics();

      // Check if we need to take action based on memory usage
      if (_estimatedMemoryUsage > _criticalMemoryUsageThreshold) {
        await _handleCriticalMemoryUsage();
      } else if (_estimatedMemoryUsage > _highMemoryUsageThreshold) {
        await _handleHighMemoryUsage();
      } else {
        // Memory usage is acceptable, reset degraded flag if it was set
        // (but don't reset if thermal degradation is active)
        if (_isPerformanceDegraded && !_isThermallyDegraded) {
          _isPerformanceDegraded = false;
          debugPrint('Performance restored to normal (memory)');
        }
      }

      // Check thermal state
      _checkThermalState();
    } catch (e) {
      debugPrint('Error monitoring resources: $e');
    }
  }

  /// Check thermal state and update metrics
  void _checkThermalState() {
    final thermalState = _thermalManager.currentThermalState;
    final temperature = _thermalManager.currentTemperature;

    debugPrint(
        'Thermal state: $thermalState, Temperature: ${temperature.toStringAsFixed(1)}°C');
  }

  /// Handle thermal state change notification from ThermalManager
  void onThermalStateChanged(bool isDegraded) {
    _isThermallyDegraded = isDegraded;

    if (isDegraded) {
      debugPrint('Performance degraded due to thermal constraints');
    } else {
      debugPrint('Thermal state normal, performance restored (thermal)');
    }
  }

  /// Update resource usage metrics
  void _updateResourceMetrics() {
    // Get active models count from AR manager
    _activeModelsCount = _arManager.activeNodes.length;

    // Get cached models count from model manager (this is an approximation)
    _cachedModelsCount = _modelManager.cacheSize;

    // Estimate memory usage based on active and cached models
    // This is a rough estimate - in a real app, you would use platform-specific
    // methods to get actual memory usage
    _estimatedMemoryUsage =
        (_activeModelsCount * 15.0) + (_cachedModelsCount * 5.0);

    debugPrint('Resource metrics updated: '
        'Memory: ${_estimatedMemoryUsage.toStringAsFixed(1)} MB, '
        'Active models: $_activeModelsCount, '
        'Cached models: $_cachedModelsCount, '
        'Temperature: ${_thermalManager.currentTemperature.toStringAsFixed(1)}°C');
  }

  /// Handle high memory usage
  Future<void> _handleHighMemoryUsage() async {
    debugPrint(
        'High memory usage detected: ${_estimatedMemoryUsage.toStringAsFixed(1)} MB');

    // Clear unused models from cache
    await _modelManager.trimCache();

    // Set performance degraded flag
    _isPerformanceDegraded = true;

    // Update metrics after taking action
    _updateResourceMetrics();
  }

  /// Handle critical memory usage
  Future<void> _handleCriticalMemoryUsage() async {
    debugPrint(
        'Critical memory usage detected: ${_estimatedMemoryUsage.toStringAsFixed(1)} MB');

    // Clear all cached models
    _modelManager.clearCache();

    // Set performance degraded flag
    _isPerformanceDegraded = true;

    // Update metrics after taking action
    _updateResourceMetrics();
  }

  /// Handle app going to background
  void onAppBackground() {
    debugPrint('App went to background');
    _isInForeground = false;

    // Pause AR session
    _pauseARSession();
  }

  /// Handle app coming to foreground
  void onAppForeground() {
    debugPrint('App came to foreground');
    _isInForeground = true;

    // Resume AR session
    _resumeARSession();
  }

  /// Pause AR session to conserve resources
  void _pauseARSession() {
    // Stop resource monitoring
    _stopResourceMonitoring();

    // Notify AR manager to pause
    _arManager.pauseSession();

    debugPrint('AR session paused');
  }

  /// Resume AR session
  void _resumeARSession() {
    // Start resource monitoring
    _startResourceMonitoring();

    // Notify AR manager to resume
    _arManager.resumeSession();

    debugPrint('AR session resumed');
  }

  /// Dispose resources
  void dispose() {
    _stopResourceMonitoring();
    _thermalManager.dispose();
    debugPrint('ResourceManager disposed');
  }
}

/// App lifecycle observer to detect when app goes to background/foreground
class _AppLifecycleObserver with WidgetsBindingObserver {
  final ResourceManager _resourceManager;

  _AppLifecycleObserver(this._resourceManager) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resourceManager.onAppForeground();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _resourceManager.onAppBackground();
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
