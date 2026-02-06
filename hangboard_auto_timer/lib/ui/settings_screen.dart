import 'package:flutter/material.dart';
import '../logic/hang_controller.dart';
import '../storage/settings_service.dart';

/// Settings screen for configuring timing thresholds.
class SettingsScreen extends StatefulWidget {
  final HangConfig currentConfig;
  final bool debugOverlayEnabled;
  final void Function(HangConfig config, bool debugOverlay)? onSaved;

  const SettingsScreen({
    super.key,
    required this.currentConfig,
    this.debugOverlayEnabled = false,
    this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  late int _prepMs;
  late int _upHoldMs;
  late int _downHoldMs;
  late int _stopIgnoreMs;
  late double _confMin;
  late bool _debugOverlay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentConfig != widget.currentConfig ||
        oldWidget.debugOverlayEnabled != widget.debugOverlayEnabled) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _prepMs = widget.currentConfig.prepMs;
    _upHoldMs = widget.currentConfig.upHoldMs;
    _downHoldMs = widget.currentConfig.downHoldMs;
    _stopIgnoreMs = widget.currentConfig.stopIgnoreMs;
    _confMin = widget.currentConfig.confMin;
    _debugOverlay = widget.debugOverlayEnabled;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = HangConfig(
      prepMs: _prepMs,
      upHoldMs: _upHoldMs,
      downHoldMs: _downHoldMs,
      stopIgnoreMs: _stopIgnoreMs,
      confMin: _confMin,
    );
    await _settingsService.saveConfig(config);
    await _settingsService.saveDebugOverlay(_debugOverlay);
    widget.onSaved?.call(config, _debugOverlay);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Timing Thresholds'),
          _buildSliderTile(
            title: 'Prep Countdown',
            subtitle: '${(_prepMs / 1000).toStringAsFixed(1)}s',
            value: _prepMs.toDouble(),
            min: 1000,
            max: 10000,
            divisions: 18,
            onChanged: (v) => setState(() => _prepMs = v.round()),
          ),
          _buildSliderTile(
            title: 'Arms-Up Hold to Confirm',
            subtitle: '${_upHoldMs}ms',
            value: _upHoldMs.toDouble(),
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (v) => setState(() => _upHoldMs = v.round()),
          ),
          _buildSliderTile(
            title: 'Arms-Down Hold to Confirm',
            subtitle: '${_downHoldMs}ms',
            value: _downHoldMs.toDouble(),
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (v) => setState(() => _downHoldMs = v.round()),
          ),
          _buildSliderTile(
            title: 'Stop Ignore Window',
            subtitle: '${(_stopIgnoreMs / 1000).toStringAsFixed(1)}s',
            value: _stopIgnoreMs.toDouble(),
            min: 0,
            max: 5000,
            divisions: 50,
            onChanged: (v) => setState(() => _stopIgnoreMs = v.round()),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Detection'),
          _buildSliderTile(
            title: 'Min Confidence',
            subtitle: _confMin.toStringAsFixed(2),
            value: _confMin,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (v) => setState(() => _confMin = v),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Debug'),
          SwitchListTile(
            title: const Text('Debug Overlay'),
            subtitle: const Text(
              'Show gesture & confidence on training screen',
            ),
            value: _debugOverlay,
            onChanged: (v) => setState(() => _debugOverlay = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
