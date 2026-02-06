import 'gesture_event.dart';

/// Abstract interface for pose detection services.
///
/// Implementations provide gesture event streams from platform-specific
/// pose detection (e.g., MediaPipe on Android/iOS) or fake data for testing.
abstract class PoseService {
  /// Start the pose detection pipeline.
  ///
  /// [frontCamera] selects the front-facing camera when true (default).
  Future<void> start({bool frontCamera = true});

  /// Stop the pose detection pipeline and release resources.
  Future<void> stop();

  /// Stream of gesture events detected by the pose estimator.
  Stream<GestureEvent> get gestureEvents;

  /// Whether the service is currently running.
  bool get isRunning;
}
