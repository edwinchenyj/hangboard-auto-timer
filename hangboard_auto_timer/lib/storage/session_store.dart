/// A single hang event record for persistence.
class HangRecord {
  /// Unique identifier.
  final String id;

  /// When the hang occurred.
  final DateTime timestamp;

  /// Duration of the hang in milliseconds.
  final int hangDurationMs;

  /// Duration of the rest before this hang in milliseconds.
  final int restDurationMs;

  /// Set number within the session.
  final int setNumber;

  /// Session ID to group related hangs.
  final String sessionId;

  const HangRecord({
    required this.id,
    required this.timestamp,
    required this.hangDurationMs,
    required this.restDurationMs,
    required this.setNumber,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'hangDurationMs': hangDurationMs,
    'restDurationMs': restDurationMs,
    'setNumber': setNumber,
    'sessionId': sessionId,
  };

  factory HangRecord.fromJson(Map<String, dynamic> json) {
    return HangRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      hangDurationMs: json['hangDurationMs'] as int,
      restDurationMs: json['restDurationMs'] as int,
      setNumber: json['setNumber'] as int,
      sessionId: json['sessionId'] as String,
    );
  }

  @override
  String toString() =>
      'HangRecord(id: $id, hang: ${hangDurationMs}ms, rest: ${restDurationMs}ms, '
      'set: $setNumber, session: $sessionId)';
}

/// A training session grouping multiple hang records.
class TrainingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<HangRecord> records;

  const TrainingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.records = const [],
  });

  /// Total hang time across all records in this session.
  int get totalHangMs => records.fold(0, (sum, r) => sum + r.hangDurationMs);

  /// Total rest time across all records in this session.
  int get totalRestMs => records.fold(0, (sum, r) => sum + r.restDurationMs);

  /// Number of completed hangs.
  int get hangCount => records.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'records': records.map((r) => r.toJson()).toList(),
  };

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      records:
          (json['records'] as List<dynamic>?)
              ?.map((r) => HangRecord.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Abstract interface for session persistence.
abstract class SessionStore {
  /// Save a hang record.
  Future<void> saveRecord(HangRecord record);

  /// Get all records for a session.
  Future<List<HangRecord>> getRecords(String sessionId);

  /// Save or update a training session.
  Future<void> saveSession(TrainingSession session);

  /// Get all training sessions, newest first.
  Future<List<TrainingSession>> getSessions();

  /// Delete a session and its records.
  Future<void> deleteSession(String sessionId);

  /// Clear all data.
  Future<void> clearAll();
}
