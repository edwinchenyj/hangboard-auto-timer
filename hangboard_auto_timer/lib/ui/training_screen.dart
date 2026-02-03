import 'package:flutter/material.dart';
import '../logic/hang_controller.dart';
import '../pose/pose_service.dart';
import '../storage/session_store.dart';

/// Main training screen showing the hang timer and state
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late HangController _hangController;
  late SessionStore _sessionStore;
  HangStateInfo? _currentStateInfo;
  TrainingSession? _currentSession;

  @override
  void initState() {
    super.initState();
    
    // Initialize with fake pose service for testing
    final poseService = FakePoseService();
    _hangController = HangController(poseService);
    _sessionStore = InMemorySessionStore();
    
    // Listen to state changes
    _hangController.stateStream.listen(_onStateChanged);
    
    // Start the controller
    _hangController.start();
  }

  void _onStateChanged(HangStateInfo stateInfo) {
    setState(() {
      _currentStateInfo = stateInfo;
    });

    // Track session data
    if (stateInfo.state == HangState.hang && _currentSession == null) {
      // Starting a new session
      _currentSession = TrainingSession(
        id: DateTime.now().toIso8601String(),
        startTime: DateTime.now(),
      );
    } else if (stateInfo.state == HangState.rest && 
               _currentSession != null && 
               stateInfo.hangDuration != null) {
      // Completed a hang, add to session
      final hang = HangRecord(
        startTime: DateTime.now().subtract(stateInfo.hangDuration!),
        duration: stateInfo.hangDuration!,
      );
      
      _currentSession = _currentSession!.copyWith(
        hangs: [..._currentSession!.hangs, hang],
      );
      
      // Save session (in production, might wait until user explicitly ends session)
      _sessionStore.saveSession(_currentSession!);
    }
  }

  @override
  void dispose() {
    _hangController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hangboard Auto Timer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // State indicator
              _buildStateIndicator(),
              const SizedBox(height: 48),
              
              // Timer display
              _buildTimerDisplay(),
              const SizedBox(height: 48),
              
              // Session info
              _buildSessionInfo(),
              const SizedBox(height: 24),
              
              // Instructions
              _buildInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateIndicator() {
    final stateInfo = _currentStateInfo;
    final state = stateInfo?.state ?? HangState.rest;
    
    Color stateColor;
    String stateText;
    IconData stateIcon;
    
    switch (state) {
      case HangState.rest:
        stateColor = Colors.grey;
        stateText = 'REST';
        stateIcon = Icons.accessibility_new;
        break;
      case HangState.prep:
        stateColor = Colors.orange;
        stateText = 'PREP';
        stateIcon = Icons.timer;
        break;
      case HangState.hang:
        stateColor = Colors.green;
        stateText = 'HANG';
        stateIcon = Icons.fitness_center;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: stateColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stateIcon, size: 48, color: stateColor),
          const SizedBox(width: 16),
          Text(
            stateText,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: stateColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final stateInfo = _currentStateInfo;
    
    if (stateInfo == null) {
      return const Text(
        '--:--',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
    }
    
    String displayText;
    Color textColor = Colors.black87;
    
    switch (stateInfo.state) {
      case HangState.rest:
        displayText = 'Ready';
        textColor = Colors.grey;
        break;
      case HangState.prep:
        final countdown = stateInfo.prepCountdown ?? Duration.zero;
        final seconds = (countdown.inMilliseconds / 1000.0).ceil();
        displayText = seconds.toString();
        textColor = Colors.orange;
        break;
      case HangState.hang:
        final duration = stateInfo.hangDuration ?? Duration.zero;
        final seconds = duration.inSeconds;
        final milliseconds = (duration.inMilliseconds % 1000) ~/ 100;
        displayText = '$seconds.$milliseconds';
        textColor = Colors.green;
        break;
    }
    
    return Text(
      displayText,
      style: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        color: textColor,
      ),
    );
  }

  Widget _buildSessionInfo() {
    if (_currentSession == null) {
      return const Text(
        'No active session',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Session Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Hangs',
                  _currentSession!.hangCount.toString(),
                  Icons.fitness_center,
                ),
                _buildStatItem(
                  'Total Time',
                  _formatDuration(_currentSession!.totalHangTime),
                  Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    final state = _currentStateInfo?.state ?? HangState.rest;
    
    String instruction;
    switch (state) {
      case HangState.rest:
        instruction = '👆 Raise your arms above your head to start';
        break;
      case HangState.prep:
        instruction = '⏱️ Get ready to hang...';
        break;
      case HangState.hang:
        instruction = '💪 Keep hanging! Lower arms when done';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        instruction,
        style: const TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}
