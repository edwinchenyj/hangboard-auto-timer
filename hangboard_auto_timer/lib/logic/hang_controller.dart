import 'dart:async';
import '../pose/pose_service.dart';

/// States in the hang training state machine
enum HangState {
  rest,  // Initial/idle state - waiting for user to begin
  prep,  // Preparation state - countdown before hang
  hang,  // Active hanging state - main workout timer
}

/// Configuration parameters for the hang controller
class HangConfig {
  /// Milliseconds to hold arms up before triggering PREP state
  final int upHoldMs;
  
  /// Milliseconds to hold arms down before ending HANG state
  final int downHoldMs;
  
  /// Preparation countdown duration in milliseconds
  final int prepMs;
  
  /// Grace period at start of HANG to ignore false stops
  final int stopIgnoreMs;
  
  /// Minimum confidence threshold for pose detection
  final double confMin;

  const HangConfig({
    this.upHoldMs = 400,
    this.downHoldMs = 400,
    this.prepMs = 2000,
    this.stopIgnoreMs = 800,
    this.confMin = 0.5,
  });
}

/// State information for the hang controller
class HangStateInfo {
  final HangState state;
  final Duration? elapsedTime;      // Elapsed time in current state
  final Duration? prepCountdown;    // Remaining prep countdown (PREP state only)
  final Duration? hangDuration;     // Total hang duration (HANG state only)

  HangStateInfo({
    required this.state,
    this.elapsedTime,
    this.prepCountdown,
    this.hangDuration,
  });

  HangStateInfo copyWith({
    HangState? state,
    Duration? elapsedTime,
    Duration? prepCountdown,
    Duration? hangDuration,
  }) {
    return HangStateInfo(
      state: state ?? this.state,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      prepCountdown: prepCountdown ?? this.prepCountdown,
      hangDuration: hangDuration ?? this.hangDuration,
    );
  }
}

/// Controller for hang training state machine
/// Manages transitions between REST → PREP → HANG → REST
class HangController {
  final PoseService _poseService;
  final HangConfig config;

  HangState _currentState = HangState.rest;
  StreamSubscription<PoseDetectionResult>? _poseSubscription;
  Timer? _stateTimer;
  Timer? _updateTimer;

  // Tracking for state transitions
  DateTime? _armPositionChangeTime;
  ArmPosition? _lastArmPosition;
  DateTime? _stateStartTime;
  DateTime? _hangStartTime;

  final _stateController = StreamController<HangStateInfo>.broadcast();

  HangController(this._poseService, {this.config = const HangConfig()});

  /// Stream of state updates
  Stream<HangStateInfo> get stateStream => _stateController.stream;

  /// Current state
  HangState get currentState => _currentState;

  /// Start the hang controller
  Future<void> start() async {
    await _poseService.start();
    
    // Subscribe to pose detection results
    _poseSubscription = _poseService.poseStream.listen(_handlePoseResult);
    
    // Start periodic state updates (for timers)
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _emitStateUpdate(),
    );

    _stateStartTime = DateTime.now();
    _emitStateUpdate();
  }

  /// Stop the hang controller
  Future<void> stop() async {
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    
    _stateTimer?.cancel();
    _stateTimer = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    await _poseService.stop();
  }

  /// Handle pose detection results
  void _handlePoseResult(PoseDetectionResult result) {
    // Ignore low confidence detections
    if (result.confidence < config.confMin) {
      return;
    }

    // Track arm position changes
    if (result.armPosition != _lastArmPosition) {
      _lastArmPosition = result.armPosition;
      _armPositionChangeTime = result.timestamp;
    }

    // Calculate how long current arm position has been held
    final holdDuration = _armPositionChangeTime != null
        ? result.timestamp.difference(_armPositionChangeTime!)
        : Duration.zero;

    // State machine logic
    switch (_currentState) {
      case HangState.rest:
        _handleRestState(result.armPosition, holdDuration);
        break;
      case HangState.prep:
        _handlePrepState();
        break;
      case HangState.hang:
        _handleHangState(result.armPosition, holdDuration);
        break;
    }
  }

  /// Handle REST state logic
  void _handleRestState(ArmPosition position, Duration holdDuration) {
    // Transition to PREP when arms are raised and held
    if (position == ArmPosition.up && 
        holdDuration.inMilliseconds >= config.upHoldMs) {
      _transitionToPrep();
    }
  }

  /// Handle PREP state logic
  void _handlePrepState() {
    final elapsed = DateTime.now().difference(_stateStartTime!);
    
    // Transition to HANG when prep countdown completes
    if (elapsed.inMilliseconds >= config.prepMs) {
      _transitionToHang();
    }
  }

  /// Handle HANG state logic
  void _handleHangState(ArmPosition position, Duration holdDuration) {
    final hangElapsed = DateTime.now().difference(_hangStartTime!);
    
    // Ignore arm-down signals during grace period
    if (hangElapsed.inMilliseconds < config.stopIgnoreMs) {
      return;
    }
    
    // Transition to REST when arms are lowered and held
    if (position == ArmPosition.down && 
        holdDuration.inMilliseconds >= config.downHoldMs) {
      _transitionToRest();
    }
  }

  /// Transition to PREP state
  void _transitionToPrep() {
    _currentState = HangState.prep;
    _stateStartTime = DateTime.now();
    _emitStateUpdate();
  }

  /// Transition to HANG state
  void _transitionToHang() {
    _currentState = HangState.hang;
    _stateStartTime = DateTime.now();
    _hangStartTime = DateTime.now();
    _emitStateUpdate();
  }

  /// Transition to REST state
  void _transitionToRest() {
    _currentState = HangState.rest;
    _stateStartTime = DateTime.now();
    _hangStartTime = null;
    _emitStateUpdate();
  }

  /// Emit current state information
  void _emitStateUpdate() {
    final now = DateTime.now();
    final elapsed = _stateStartTime != null 
        ? now.difference(_stateStartTime!) 
        : Duration.zero;

    Duration? prepCountdown;
    Duration? hangDuration;

    if (_currentState == HangState.prep) {
      final remaining = config.prepMs - elapsed.inMilliseconds;
      prepCountdown = Duration(milliseconds: remaining.clamp(0, config.prepMs));
    } else if (_currentState == HangState.hang && _hangStartTime != null) {
      hangDuration = now.difference(_hangStartTime!);
    }

    _stateController.add(HangStateInfo(
      state: _currentState,
      elapsedTime: elapsed,
      prepCountdown: prepCountdown,
      hangDuration: hangDuration,
    ));
  }

  /// Dispose resources
  void dispose() {
    stop();
    _stateController.close();
    _poseService.dispose();
  }
}
