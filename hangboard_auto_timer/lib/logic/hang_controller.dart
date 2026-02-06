import 'dart:async';
import '../pose/gesture_event.dart';

/// The possible states of the hang training controller.
enum HangState { rest, prep, hang }

/// UI-facing snapshot of the controller's current state.
class UiState {
  final HangState state;

  /// Elapsed hang time in milliseconds (only meaningful during [HangState.hang]).
  final int hangMs;

  /// Elapsed rest time in milliseconds (only meaningful during [HangState.rest]).
  final int restMs;

  /// Remaining prep countdown in milliseconds (only meaningful during [HangState.prep]).
  final int prepRemainingMs;

  /// Current set number (1-based).
  final int setNumber;

  const UiState({
    required this.state,
    this.hangMs = 0,
    this.restMs = 0,
    this.prepRemainingMs = 0,
    this.setNumber = 1,
  });

  UiState copyWith({
    HangState? state,
    int? hangMs,
    int? restMs,
    int? prepRemainingMs,
    int? setNumber,
  }) {
    return UiState(
      state: state ?? this.state,
      hangMs: hangMs ?? this.hangMs,
      restMs: restMs ?? this.restMs,
      prepRemainingMs: prepRemainingMs ?? this.prepRemainingMs,
      setNumber: setNumber ?? this.setNumber,
    );
  }

  @override
  String toString() =>
      'UiState(state: $state, hangMs: $hangMs, restMs: $restMs, '
      'prepRemainingMs: $prepRemainingMs, setNumber: $setNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiState &&
          state == other.state &&
          hangMs == other.hangMs &&
          restMs == other.restMs &&
          prepRemainingMs == other.prepRemainingMs &&
          setNumber == other.setNumber;

  @override
  int get hashCode =>
      Object.hash(state, hangMs, restMs, prepRemainingMs, setNumber);
}

/// Configuration for the hang controller timing thresholds.
class HangConfig {
  /// Prep countdown duration in milliseconds.
  final int prepMs;

  /// How long arms must stay UP to confirm a hang start, in ms.
  final int upHoldMs;

  /// How long arms must stay DOWN to confirm hang end / rest, in ms.
  final int downHoldMs;

  /// After entering HANG state, ignore ARMS_DOWN for this many ms.
  final int stopIgnoreMs;

  /// Minimum confidence threshold for gesture events.
  final double confMin;

  const HangConfig({
    this.prepMs = 3000,
    this.upHoldMs = 500,
    this.downHoldMs = 300,
    this.stopIgnoreMs = 1000,
    this.confMin = 0.5,
  });

  HangConfig copyWith({
    int? prepMs,
    int? upHoldMs,
    int? downHoldMs,
    int? stopIgnoreMs,
    double? confMin,
  }) {
    return HangConfig(
      prepMs: prepMs ?? this.prepMs,
      upHoldMs: upHoldMs ?? this.upHoldMs,
      downHoldMs: downHoldMs ?? this.downHoldMs,
      stopIgnoreMs: stopIgnoreMs ?? this.stopIgnoreMs,
      confMin: confMin ?? this.confMin,
    );
  }
}

/// Callback for state transition events (e.g., beeps/haptics).
typedef TransitionCallback = void Function(HangState from, HangState to);

/// Callback when a hang rep is completed.
typedef HangCompletedCallback =
    void Function(int hangDurationMs, int restDurationMs);

/// The core state machine for the hangboard auto-timer.
///
/// States: REST → (arms up hold confirmed) → PREP → (countdown) → HANG
///         HANG → (arms down hold confirmed, after STOP_IGNORE_MS) → REST
///
/// Feed gesture events via [onGestureEvent].
/// Listen to state changes via [uiStateStream].
class HangController {
  HangConfig _config;
  HangConfig get config => _config;

  HangState _state = HangState.rest;
  HangState get state => _state;

  int _setNumber = 1;
  int get setNumber => _setNumber;

  // Timestamps for hold-to-confirm logic
  int? _armsUpSince; // monotonic ms when arms-up was first seen
  int? _armsDownSince; // monotonic ms when arms-down was first seen

  // Timestamps for state entry
  int _hangStartMs = 0;
  int _restStartMs = 0;
  int _prepStartMs = 0;
  int _lastHangDurationMs = 0;

  // Timer for prep countdown
  Timer? _prepTimer;

  // Timer for UI updates
  Timer? _uiUpdateTimer;

  // Stream controller for UI state updates
  final StreamController<UiState> _uiStateController =
      StreamController<UiState>.broadcast();

  /// Stream of UI state snapshots.
  Stream<UiState> get uiStateStream => _uiStateController.stream;

  /// Optional callback when a state transition occurs.
  TransitionCallback? onTransition;

  /// Optional callback when a hang rep is completed (HANG → REST).
  HangCompletedCallback? onHangCompleted;

  HangController({
    HangConfig config = const HangConfig(),
    this.onTransition,
    this.onHangCompleted,
  }) : _config = config {
    _restStartMs = _now();
    _startUiUpdates();
  }

  /// Update configuration (e.g., from settings screen).
  void updateConfig(HangConfig newConfig) {
    _config = newConfig;
  }

  /// Process an incoming gesture event.
  void onGestureEvent(GestureEvent event) {
    // Filter low-confidence events
    if (event.confidence != null && event.confidence! < _config.confMin) {
      return;
    }

    final now = event.tMs;

    switch (_state) {
      case HangState.rest:
        _handleRestState(event, now);
        break;
      case HangState.prep:
        _handlePrepState(event, now);
        break;
      case HangState.hang:
        _handleHangState(event, now);
        break;
    }
  }

  void _handleRestState(GestureEvent event, int now) {
    if (event.gesture == GestureType.armsUp) {
      // Start or continue tracking arms-up hold
      _armsUpSince ??= now;
      final held = now - _armsUpSince!;
      if (held >= _config.upHoldMs) {
        // Arms-up hold confirmed → transition to PREP
        _transitionTo(HangState.prep, now);
      }
    } else {
      // Arms not up → reset the hold timer
      _armsUpSince = null;
    }
  }

  void _handlePrepState(GestureEvent event, int now) {
    if (event.gesture != GestureType.armsUp) {
      // Arms dropped during prep → cancel and go back to REST
      _cancelPrep();
      _transitionTo(HangState.rest, now);
    }
    // If arms still up, prep countdown continues (managed by timer)
  }

  void _handleHangState(GestureEvent event, int now) {
    final hangElapsed = now - _hangStartMs;

    if (event.gesture == GestureType.armsDown) {
      // Check if we're past the stop-ignore window
      if (hangElapsed < _config.stopIgnoreMs) {
        // Ignore early arm drops
        _armsDownSince = null;
        return;
      }

      // Start or continue tracking arms-down hold
      _armsDownSince ??= now;
      final held = now - _armsDownSince!;
      if (held >= _config.downHoldMs) {
        // Arms-down hold confirmed → transition to REST
        _lastHangDurationMs = now - _hangStartMs;
        _transitionTo(HangState.rest, now);
      }
    } else {
      // Arms not down → reset the hold timer
      _armsDownSince = null;
    }
  }

  void _transitionTo(HangState newState, int now) {
    final oldState = _state;
    _state = newState;

    // Reset hold trackers
    _armsUpSince = null;
    _armsDownSince = null;

    switch (newState) {
      case HangState.rest:
        _cancelPrep();
        _restStartMs = now;
        if (oldState == HangState.hang) {
          _setNumber++;
          final restDuration = 0; // Rest just started
          onHangCompleted?.call(_lastHangDurationMs, restDuration);
        }
        break;
      case HangState.prep:
        _prepStartMs = now;
        _startPrepCountdown(now);
        break;
      case HangState.hang:
        _hangStartMs = now;
        break;
    }

    onTransition?.call(oldState, newState);
    _emitUiState(now);
  }

  void _startPrepCountdown(int startMs) {
    _cancelPrep();
    _prepTimer = Timer(Duration(milliseconds: _config.prepMs), () {
      // Prep countdown completed → transition to HANG
      final now = _now();
      _transitionTo(HangState.hang, now);
    });
  }

  void _cancelPrep() {
    _prepTimer?.cancel();
    _prepTimer = null;
  }

  void _startUiUpdates() {
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _emitUiState(_now());
    });
  }

  void _emitUiState(int now) {
    if (_uiStateController.isClosed) return;

    final uiState = UiState(
      state: _state,
      hangMs: _state == HangState.hang ? now - _hangStartMs : 0,
      restMs: _state == HangState.rest ? now - _restStartMs : 0,
      prepRemainingMs: _state == HangState.prep
          ? (_config.prepMs - (now - _prepStartMs)).clamp(0, _config.prepMs)
          : 0,
      setNumber: _setNumber,
    );
    _uiStateController.add(uiState);
  }

  /// Reset the controller to initial state.
  void reset() {
    _cancelPrep();
    _state = HangState.rest;
    _setNumber = 1;
    _armsUpSince = null;
    _armsDownSince = null;
    _restStartMs = _now();
    _emitUiState(_now());
  }

  /// Dispose of resources.
  void dispose() {
    _cancelPrep();
    _uiUpdateTimer?.cancel();
    _uiStateController.close();
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
