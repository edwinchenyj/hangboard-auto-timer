/// Represents a single hang in a training session
class HangRecord {
  final DateTime startTime;
  final Duration duration;
  final DateTime endTime;

  HangRecord({
    required this.startTime,
    required this.duration,
  }) : endTime = startTime.add(duration);

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'duration': duration.inMilliseconds,
      'endTime': endTime.toIso8601String(),
    };
  }

  factory HangRecord.fromJson(Map<String, dynamic> json) {
    return HangRecord(
      startTime: DateTime.parse(json['startTime'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
    );
  }
}

/// Represents a complete training session
class TrainingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<HangRecord> hangs;

  TrainingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.hangs = const [],
  });

  /// Total number of hangs in this session
  int get hangCount => hangs.length;

  /// Total duration of all hangs combined
  Duration get totalHangTime {
    return hangs.fold(
      Duration.zero,
      (total, hang) => total + hang.duration,
    );
  }

  /// Session duration (from start to end)
  Duration? get sessionDuration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'hangs': hangs.map((h) => h.toJson()).toList(),
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      hangs: (json['hangs'] as List<dynamic>)
          .map((h) => HangRecord.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Create a copy with modifications
  TrainingSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<HangRecord>? hangs,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hangs: hangs ?? this.hangs,
    );
  }
}

/// Abstract interface for storing training sessions
abstract class SessionStore {
  /// Save a training session
  Future<void> saveSession(TrainingSession session);

  /// Get a specific session by ID
  Future<TrainingSession?> getSession(String id);

  /// Get all training sessions
  Future<List<TrainingSession>> getAllSessions();

  /// Delete a session
  Future<void> deleteSession(String id);

  /// Clear all sessions
  Future<void> clearAll();
}

/// In-memory implementation of SessionStore for testing
/// In production, this would be replaced with persistent storage (e.g., SQLite, SharedPreferences)
class InMemorySessionStore implements SessionStore {
  final Map<String, TrainingSession> _sessions = {};

  @override
  Future<void> saveSession(TrainingSession session) async {
    _sessions[session.id] = session;
  }

  @override
  Future<TrainingSession?> getSession(String id) async {
    return _sessions[id];
  }

  @override
  Future<List<TrainingSession>> getAllSessions() async {
    final sessions = _sessions.values.toList();
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime)); // Most recent first
    return sessions;
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _sessions.clear();
  }
}
