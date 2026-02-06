import 'package:flutter/material.dart';
import '../storage/session_store.dart';

/// Screen showing training history with past sessions and hang records.
class HistoryScreen extends StatefulWidget {
  final SessionStore sessionStore;

  const HistoryScreen({super.key, required this.sessionStore});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TrainingSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await widget.sessionStore.getSessions();
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    await widget.sessionStore.deleteSession(sessionId);
    await _loadSessions();
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '$seconds.${(ms % 1000) ~/ 100}s';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _showClearAllDialog(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No training sessions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start training to see your history here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return _SessionCard(
                    session: session,
                    formatDuration: _formatDuration,
                    formatDateTime: _formatDateTime,
                    onDelete: () => _deleteSession(session.id),
                  );
                },
              ),
            ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete all training sessions. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.sessionStore.clearAll();
              await _loadSessions();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingSession session;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDateTime;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.formatDuration,
    required this.formatDateTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          formatDateTime(session.startTime),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${session.hangCount} hangs · '
          'Total hang: ${formatDuration(session.totalHangMs)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
        children: [
          if (session.records.isEmpty)
            const ListTile(
              title: Text(
                'No hang records',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...session.records.map(
              (record) => ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  child: Text('${record.setNumber}'),
                ),
                title: Text('Hang: ${formatDuration(record.hangDurationMs)}'),
                subtitle: Text(
                  'Rest: ${formatDuration(record.restDurationMs)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
