import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_store.dart';

/// [SessionStore] implementation using SharedPreferences and local JSON.
class LocalSessionStore extends SessionStore {
  static const _sessionsKey = 'training_sessions';

  @override
  Future<void> saveRecord(HangRecord record) async {
    final sessions = await getSessions();
    final idx = sessions.indexWhere((s) => s.id == record.sessionId);
    if (idx >= 0) {
      final session = sessions[idx];
      final updatedRecords = [...session.records, record];
      sessions[idx] = TrainingSession(
        id: session.id,
        startTime: session.startTime,
        endTime: session.endTime,
        records: updatedRecords,
      );
    }
    await _saveSessions(sessions);
  }

  @override
  Future<List<HangRecord>> getRecords(String sessionId) async {
    final sessions = await getSessions();
    final session = sessions.where((s) => s.id == sessionId).firstOrNull;
    return session?.records ?? [];
  }

  @override
  Future<void> saveSession(TrainingSession session) async {
    final sessions = await getSessions();
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    await _saveSessions(sessions);
  }

  @override
  Future<List<TrainingSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionsKey);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
    return jsonList
        .map((j) => TrainingSession.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await _saveSessions(sessions);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  Future<void> _saveSessions(List<TrainingSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, jsonStr);
  }
}
