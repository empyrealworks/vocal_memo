import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/providers/settings_provider.dart';
import 'package:vocal_memo/services/rating_service.dart';

import '../models/recording_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.watch(settingsProvider.notifier);

    void updateSettings(RecordingSettings newSettings) {
      notifier.update(newSettings);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Recording Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Auto Gain Control
          SwitchListTile(
            title: const Text("Auto Gain Control"),
            subtitle: const Text("Automatically adjust microphone gain"),
            value: settings.autoGainControl,
            onChanged: (v) =>
                updateSettings(settings.copyWith(autoGainControl: v)),
          ),

          // Noise Suppression
          SwitchListTile(
            title: const Text("Noise Suppression"),
            subtitle: const Text("Reduce background noise"),
            value: settings.noiseSuppression,
            onChanged: (v) =>
                updateSettings(settings.copyWith(noiseSuppression: v)),
          ),

          // Echo Cancellation
          SwitchListTile(
            title: const Text("Echo Cancellation"),
            subtitle: const Text("Minimize echo in recordings"),
            value: settings.echoCancellation,
            onChanged: (v) =>
                updateSettings(settings.copyWith(echoCancellation: v)),
          ),

          // Device Selection
          ListTile(
            title: const Text("Recording Device"),
            subtitle: const Text("Choose input source"),
            trailing: DropdownButton<String>(
              value: settings.device,
              items: const [
                DropdownMenuItem(
                  value: "Default Microphone",
                  child: Text("Default Microphone"),
                ),
                DropdownMenuItem(
                  value: "External Mic",
                  child: Text("External Mic"),
                ),
              ],
              onChanged: (v) => updateSettings(settings.copyWith(device: v!)),
            ),
          ),

          // Bitrate
          ListTile(
            title: const Text("Bitrate (kbps)"),
            subtitle: Slider(
              value: settings.bitRate.toDouble(),
              min: 64000,
              max: 320000,
              divisions: 8,
              label: "${settings.bitRate ~/ 1000}",
              onChanged: (v) =>
                  updateSettings(settings.copyWith(bitRate: v.toInt())),
            ),
          ),

          // Sample Rate
          ListTile(
            title: const Text("Sample Rate (Hz)"),
            subtitle: Slider(
              value: settings.sampleRate.toDouble(),
              min: 8000,
              max: 48000,
              divisions: 4,
              label: "${settings.sampleRate}",
              onChanged: (v) =>
                  updateSettings(settings.copyWith(sampleRate: v.toInt())),
            ),
          ),

          // Audio Format
          ListTile(
            title: const Text("Audio Format"),
            subtitle: const Text("Select recording format"),
            trailing: DropdownButton<String>(
              value: settings.audioFormat,
              items: const [
                DropdownMenuItem(value: "m4a", child: Text("M4A (AAC)")),
                DropdownMenuItem(value: "wav", child: Text("WAV")),
                DropdownMenuItem(value: "aac", child: Text("AAC")),
                DropdownMenuItem(value: "flac", child: Text("FLAC")),
              ],
              onChanged: (v) =>
                  updateSettings(settings.copyWith(audioFormat: v!)),
            ),
          ),

          // Amplitude Visualization
          SwitchListTile(
            title: const Text("Show Live Waveform"),
            subtitle: const Text("Display real-time waveform during recording"),
            value: settings.showWaveform,
            inactiveTrackColor: Colors.grey,
            onChanged: (v) {
              updateSettings(settings.copyWith(showWaveform: v));
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            "App Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Theme Mode
          ListTile(
            title: const Text("Theme"),
            subtitle: const Text("Choose app theme mode"),
            trailing: DropdownButton<String>(
              value: settings.themeMode,
              items: const [
                DropdownMenuItem(
                  value: "System",
                  child: Text("System Default"),
                ),
                DropdownMenuItem(value: "Light", child: Text("Light")),
                DropdownMenuItem(value: "Dark", child: Text("Dark")),
              ],
              onChanged: (v) =>
                  updateSettings(settings.copyWith(themeMode: v!)),
            ),
          ),

          // Reset Settings
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text("Reset All Settings"),
            subtitle: const Text("Restore default preferences"),
            onTap: () => notifier.reset(),
          ),

          // Rate App
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: const Text("Rate This App"),
            subtitle: const Text("Tell others what you think!"),
            onTap: () async {
              await RatingService.requestReview();
            },
          ),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            subtitle: const Text("App version, developer info"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Vocal Memo",
                applicationVersion: "1.3.0",
                applicationLegalese: "© 2026 Adeleke Olasope",
              );
            },
          ),
        ],
      ),
    );
  }
}
