import 'dart:async';
import 'package:flutter/material.dart';
import 'logic/hang_controller.dart';
import 'pose/fake_pose_service.dart';
import 'pose/pose_service.dart';
import 'storage/local_session_store.dart';
import 'storage/session_store.dart';
import 'storage/settings_service.dart';
import 'ui/history_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/training_screen.dart';

void main() {
  runApp(const HangboardApp());
}

class HangboardApp extends StatelessWidget {
  const HangboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hangboard Auto Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Root screen with bottom navigation between Training, History, Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Services
  PoseService? _poseService;
  HangController? _controller;
  SessionStore? _sessionStore;
  final _settingsService = SettingsService();

  // State
  HangConfig _config = const HangConfig();
  bool _debugOverlay = false;
  bool _initialized = false;
  String _currentSessionId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load saved settings
      _config = await _settingsService.loadConfig();
      _debugOverlay = await _settingsService.loadDebugOverlay();

      // Initialize services
      _poseService = FakePoseService();
      _controller = HangController(
        config: _config,
        onHangCompleted: _onHangCompleted,
      );
      _sessionStore = LocalSessionStore();

      // Start a new session
      _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await _sessionStore!.saveSession(
        TrainingSession(id: _currentSessionId, startTime: DateTime.now()),
      );

      // Start pose detection
      await _poseService!.start();

      if (!mounted) return;
      setState(() => _initialized = true);
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (!mounted) return;
      setState(() => _initialized = true); // Show UI even on error
    }
  }

  void _onHangCompleted(int hangDurationMs, int restDurationMs) {
    _sessionStore?.saveRecord(
      HangRecord(
        id: 'record_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        hangDurationMs: hangDurationMs,
        restDurationMs: restDurationMs,
        setNumber: _controller!.setNumber - 1,
        sessionId: _currentSessionId,
      ),
    );
  }

  void _onSettingsSaved(HangConfig config, bool debugOverlay) {
    setState(() {
      _config = config;
      _debugOverlay = debugOverlay;
    });
    _controller?.updateConfig(config);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TrainingScreen(
            poseService: _poseService!,
            controller: _controller!,
            showDebugOverlay: _debugOverlay,
          ),
          HistoryScreen(sessionStore: _sessionStore!),
          SettingsScreen(
            currentConfig: _config,
            debugOverlayEnabled: _debugOverlay,
            onSaved: _onSettingsSaved,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Train',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
