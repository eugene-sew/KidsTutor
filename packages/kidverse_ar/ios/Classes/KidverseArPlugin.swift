import Flutter
import UIKit
import ARKit

public class KidverseArPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "kidverse_ar", binaryMessenger: registrar.messenger())
    let instance = KidverseArPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "queryCapabilities":
      result(queryCapabilities())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func queryCapabilities() -> [String: Bool] {
    var planeDetection = ARWorldTrackingConfiguration.isSupported
    var imageTracking = ARImageTrackingConfiguration.isSupported
    var depth = false
    var mesh = false

    if #available(iOS 14.0, *) {
      depth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
    if #available(iOS 13.4, *) {
      mesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    let geospatial = false // ARKit does not expose ARCore Geospatial equivalent.

    return [
      "planeDetection": planeDetection,
      "imageTracking": imageTracking,
      "depth": depth,
      "mesh": mesh,
      "geospatial": geospatial,
    ]
  }
}

