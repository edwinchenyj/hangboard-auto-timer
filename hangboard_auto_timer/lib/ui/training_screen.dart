import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/hang_controller.dart';
import '../pose/gesture_event.dart';
import '../pose/pose_service.dart';

/// The main training screen with large timers, state colors, and feedback.
class TrainingScreen extends StatefulWidget {
  final PoseService poseService;
  final HangController controller;
  final bool showDebugOverlay;

  const TrainingScreen({
    super.key,
    required this.poseService,
    required this.controller,
    this.showDebugOverlay = false,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  StreamSubscription<GestureEvent>? _gestureSub;
  StreamSubscription<UiState>? _uiSub;
  UiState _uiState = const UiState(state: HangState.rest);
  GestureEvent? _lastGesture;
  HangState? _previousState;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // Listen to gesture events and forward to controller
    _gestureSub = widget.poseService.gestureEvents.listen((event) {
      setState(() {
        _lastGesture = event;
      });
      widget.controller.onGestureEvent(event);
    });

    // Listen to UI state updates
    _uiSub = widget.controller.uiStateStream.listen((uiState) {
      // Trigger haptic/beep on state transitions
      if (_previousState != null && _previousState != uiState.state) {
        _onStateTransition(_previousState!, uiState.state);
      }
      _previousState = uiState.state;
      setState(() {
        _uiState = uiState;
      });
    });
  }

  void _onStateTransition(HangState from, HangState to) {
    if (from == HangState.prep && to == HangState.hang) {
      // PREP → HANG: strong haptic + would beep
      HapticFeedback.heavyImpact();
    } else if (from == HangState.hang && to == HangState.rest) {
      // HANG → REST: medium haptic
      HapticFeedback.mediumImpact();
    } else if (from == HangState.rest && to == HangState.prep) {
      // REST → PREP: light haptic
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    _uiSub?.cancel();
    super.dispose();
  }

  Color _stateColor(HangState state) {
    switch (state) {
      case HangState.rest:
        return const Color(0xFF2196F3); // Blue
      case HangState.prep:
        return const Color(0xFFFFC107); // Amber
      case HangState.hang:
        return const Color(0xFF4CAF50); // Green
    }
  }

  String _stateLabel(HangState state) {
    switch (state) {
      case HangState.rest:
        return 'REST';
      case HangState.prep:
        return 'PREP';
      case HangState.hang:
        return 'HANG';
    }
  }

  String _formatMs(int ms) {
    final seconds = (ms / 1000).floor();
    final tenths = ((ms % 1000) / 100).floor();
    return '$seconds.${tenths}s';
  }

  String _primaryTimerText() {
    switch (_uiState.state) {
      case HangState.rest:
        return _formatMs(_uiState.restMs);
      case HangState.prep:
        return _formatMs(_uiState.prepRemainingMs);
      case HangState.hang:
        return _formatMs(_uiState.hangMs);
    }
  }

  String _primaryTimerLabel() {
    switch (_uiState.state) {
      case HangState.rest:
        return 'Rest Time';
      case HangState.prep:
        return 'Get Ready';
      case HangState.hang:
        return 'Hang Time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(_uiState.state);

    return Scaffold(
      backgroundColor: color.withAlpha(30),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // State indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      _stateLabel(_uiState.state),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary timer label
                  Text(
                    _primaryTimerLabel(),
                    style: TextStyle(
                      fontSize: 20,
                      color: color.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Primary timer (large)
                  Text(
                    _primaryTimerText(),
                    style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w300,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Set counter
                  Text(
                    'Set ${_uiState.setNumber}',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Debug overlay
            if (widget.showDebugOverlay && _lastGesture != null)
              Positioned(
                top: 16,
                right: 16,
                child: _DebugOverlay(gesture: _lastGesture!, uiState: _uiState),
              ),
          ],
        ),
      ),
    );
  }
}

/// Debug overlay showing raw gesture data and confidence.
class _DebugOverlay extends StatelessWidget {
  final GestureEvent gesture;
  final UiState uiState;

  const _DebugOverlay({required this.gesture, required this.uiState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gesture: ${gesture.gesture.name}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'Confidence: ${gesture.confidence?.toStringAsFixed(2) ?? "N/A"}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'State: ${uiState.state.name}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'tMs: ${gesture.tMs}',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
