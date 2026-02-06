/// Possible gesture types detected by pose estimation.
enum GestureType { armsUp, armsDown, unknown }

/// A single gesture event from the pose detection pipeline.
class GestureEvent {
  /// Monotonic timestamp in milliseconds.
  final int tMs;

  /// The detected gesture.
  final GestureType gesture;

  /// Detection confidence in [0, 1]. May be null if unavailable.
  final double? confidence;

  const GestureEvent({
    required this.tMs,
    required this.gesture,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'tMs': tMs,
    'gesture': gesture.name,
    if (confidence != null) 'confidence': confidence,
  };

  factory GestureEvent.fromJson(Map<String, dynamic> json) {
    return GestureEvent(
      tMs: json['tMs'] as int,
      gesture: GestureType.values.firstWhere(
        (g) => g.name == json['gesture'],
        orElse: () => GestureType.unknown,
      ),
      confidence: json['confidence'] as double?,
    );
  }

  @override
  String toString() =>
      'GestureEvent(tMs: $tMs, gesture: $gesture, confidence: $confidence)';
}
