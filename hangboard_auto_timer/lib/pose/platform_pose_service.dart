import 'dart:async';
import 'package:flutter/services.dart';
import 'gesture_event.dart';
import 'pose_service.dart';

/// [PoseService] implementation using Flutter platform channels.
///
/// Communicates with native Android/iOS MediaPipe Pose implementations
/// via MethodChannel and EventChannel.
class PlatformPoseService extends PoseService {
  static const _methodChannel = MethodChannel('com.hangboard.auto_timer/pose');
  static const _eventChannel = EventChannel(
    'com.hangboard.auto_timer/pose_events',
  );

  bool _running = false;
  StreamController<GestureEvent>? _controller;
  StreamSubscription<dynamic>? _platformSub;

  @override
  Future<void> start({bool frontCamera = true}) async {
    if (_running) return;

    await _methodChannel.invokeMethod('start', {'frontCamera': frontCamera});

    _running = true;
    _controller = StreamController<GestureEvent>.broadcast();

    _platformSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final gestureStr = event['gesture'] as String? ?? 'UNKNOWN';
          GestureType gesture;
          switch (gestureStr) {
            case 'ARMS_UP':
              gesture = GestureType.armsUp;
              break;
            case 'ARMS_DOWN':
              gesture = GestureType.armsDown;
              break;
            default:
              gesture = GestureType.unknown;
          }

          final gestureEvent = GestureEvent(
            tMs: event['tMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
            gesture: gesture,
            confidence: (event['confidence'] as num?)?.toDouble(),
          );
          _controller?.add(gestureEvent);
        }
      },
      onError: (Object error) {
        _controller?.addError(error);
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_running) return;

    await _methodChannel.invokeMethod('stop');
    _running = false;
    await _platformSub?.cancel();
    _platformSub = null;
    await _controller?.close();
    _controller = null;
  }

  @override
  Stream<GestureEvent> get gestureEvents =>
      _controller?.stream ?? const Stream.empty();

  @override
  bool get isRunning => _running;
}
