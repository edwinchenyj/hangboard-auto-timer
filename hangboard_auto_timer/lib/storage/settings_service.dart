import 'package:shared_preferences/shared_preferences.dart';
import '../logic/hang_controller.dart';

/// Manages persisted application settings.
class SettingsService {
  static const _prepMsKey = 'settings_prep_ms';
  static const _upHoldMsKey = 'settings_up_hold_ms';
  static const _downHoldMsKey = 'settings_down_hold_ms';
  static const _stopIgnoreMsKey = 'settings_stop_ignore_ms';
  static const _confMinKey = 'settings_conf_min';
  static const _debugOverlayKey = 'settings_debug_overlay';

  /// Load settings from local storage, returning defaults if not set.
  Future<HangConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return HangConfig(
      prepMs: prefs.getInt(_prepMsKey) ?? 3000,
      upHoldMs: prefs.getInt(_upHoldMsKey) ?? 500,
      downHoldMs: prefs.getInt(_downHoldMsKey) ?? 300,
      stopIgnoreMs: prefs.getInt(_stopIgnoreMsKey) ?? 1000,
      confMin: prefs.getDouble(_confMinKey) ?? 0.5,
    );
  }

  /// Save settings to local storage.
  Future<void> saveConfig(HangConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prepMsKey, config.prepMs);
    await prefs.setInt(_upHoldMsKey, config.upHoldMs);
    await prefs.setInt(_downHoldMsKey, config.downHoldMs);
    await prefs.setInt(_stopIgnoreMsKey, config.stopIgnoreMs);
    await prefs.setDouble(_confMinKey, config.confMin);
  }

  /// Load the debug overlay toggle setting.
  Future<bool> loadDebugOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_debugOverlayKey) ?? false;
  }

  /// Save the debug overlay toggle setting.
  Future<void> saveDebugOverlay(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugOverlayKey, enabled);
  }
}
