import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var gestureDetector: PoseGestureDetector?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController

    // Method channel for start/stop
    let methodChannel = FlutterMethodChannel(
      name: "com.hangboard.auto_timer/pose",
      binaryMessenger: controller.binaryMessenger
    )

    // Event channel for gesture events
    let eventChannel = FlutterEventChannel(
      name: "com.hangboard.auto_timer/pose_events",
      binaryMessenger: controller.binaryMessenger
    )

    let streamHandler = GestureStreamHandler()
    eventChannel.setStreamHandler(streamHandler)

    methodChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any]
        let frontCamera = args?["frontCamera"] as? Bool ?? true
        do {
          self?.gestureDetector = PoseGestureDetector()
          try self?.gestureDetector?.start(frontCamera: frontCamera) { event in
            DispatchQueue.main.async {
              streamHandler.eventSink?(event)
            }
          }
          result(nil)
        } catch {
          result(FlutterError(code: "CAMERA_ERROR", message: error.localizedDescription, details: nil))
        }
      case "stop":
        self?.gestureDetector?.stop()
        self?.gestureDetector = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class GestureStreamHandler: NSObject, FlutterStreamHandler {
  var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
