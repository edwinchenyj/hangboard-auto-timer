import 'dart:async';
import 'gesture_event.dart';
import 'pose_service.dart';

/// A fake [PoseService] that emits a repeating pattern of gesture events
/// for testing and development without requiring camera/ML.
///
/// Pattern: REST (armsDown 3s) → armsUp hold → PREP → HANG (armsUp 7s) → armsDown → REST ...
class FakePoseService extends PoseService {
  StreamController<GestureEvent>? _controller;
  Timer? _timer;
  bool _running = false;
  int _tick = 0;

  /// Interval between fake events in milliseconds.
  final int intervalMs;

  FakePoseService({this.intervalMs = 200});

  @override
  Future<void> start({bool frontCamera = true}) async {
    if (_running) return;
    _running = true;
    _tick = 0;
    _controller = StreamController<GestureEvent>.broadcast();

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_controller == null || _controller!.isClosed) return;
      _tick++;
      final event = _generateEvent(_tick);
      _controller!.add(event);
    });
  }

  @override
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }

  @override
  Stream<GestureEvent> get gestureEvents =>
      _controller?.stream ?? const Stream.empty();

  @override
  bool get isRunning => _running;

  /// Generates a fake event based on the tick count.
  /// Cycle: 15 ticks armsDown (3s) → 35 ticks armsUp (7s) → repeat
  GestureEvent _generateEvent(int tick) {
    final cyclePosition = tick % 50; // 50 ticks = 10 seconds total
    final isArmsUp = cyclePosition >= 15; // First 15 ticks = rest, rest = hang

    return GestureEvent(
      tMs: DateTime.now().millisecondsSinceEpoch,
      gesture: isArmsUp ? GestureType.armsUp : GestureType.armsDown,
      confidence: 0.95,
    );
  }
}
