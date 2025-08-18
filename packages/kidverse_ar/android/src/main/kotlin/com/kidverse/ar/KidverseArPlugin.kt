package com.kidverse.ar

import androidx.annotation.NonNull
import android.content.pm.PackageManager
import android.os.Build
import android.content.Context

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class KidverseArPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var appContext: Context? = null

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "kidverse_ar")
    channel.setMethodCallHandler(this)
    appContext = binding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "queryCapabilities" -> result.success(queryCapabilities())
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    appContext = null
  }

  private fun queryCapabilities(): Map<String, Boolean> {
    val context = appContext ?: return mapOf(
      "planeDetection" to false,
      "imageTracking" to false,
      "depth" to false,
      "mesh" to false,
      "geospatial" to false,
    )

    val pm: PackageManager = context.packageManager
    val hasArCoreServices = try { pm.getPackageInfo("com.google.ar.core", 0); true } catch (e: Exception) { false }

    // Baseline checks
    val planeDetection = hasArCoreServices
    val imageTracking = hasArCoreServices
    val geospatial = hasArCoreServices

    // Depth availability: ARCore Depth requires supported device and Google Play Services for AR >= 1.18.
    // Without linking ARCore SDK, approximate with ARCore presence and Android 10+ (not strictly required but common).
    val depth = hasArCoreServices && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    // Meshing: ARCore doesn't offer full scene mesh parity with ARKit; keep false for now.
    val mesh = false

    return mapOf(
      "planeDetection" to planeDetection,
      "imageTracking" to imageTracking,
      "depth" to depth,
      "mesh" to mesh,
      "geospatial" to geospatial,
    )
  }
}

