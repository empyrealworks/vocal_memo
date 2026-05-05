import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recording_settings.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsProvider =
StateNotifierProvider<SettingsNotifier, RecordingSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});

class SettingsNotifier extends StateNotifier<RecordingSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(_service.getSettings());

  Future<void> update(RecordingSettings newSettings) async {
    state = newSettings;
    await _service.updateSettings(newSettings);
  }

  ThemeMode get currentThemeMode {
    switch (state.themeMode) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> reset() async {
    await _service.resetSettings();
    state = _service.getSettings();
  }
}
