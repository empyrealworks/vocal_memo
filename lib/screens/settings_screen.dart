import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/providers/settings_provider.dart';
import 'package:vocal_memo/services/rating_service.dart';

import '../models/recording_settings.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.watch(settingsProvider.notifier);
    final authState = ref.watch(authStateProvider);

    void updateSettings(RecordingSettings newSettings) {
      notifier.update(newSettings);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Account ─────────────────────────────────────────────────────
          const Text(
            "Account",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          authState.when(
            data: (user) {
              if (user == null) {
                return ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text("Create Account"),
                  subtitle:
                  const Text("Sign up for cloud backup & premium features"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const AuthScreen(showBenefits: true),
                      ),
                    );
                  },
                );
              }

              return Column(
                children: [
                  // Account info
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text("Account"),
                    subtitle: Text(user.email ?? 'Signed in'),
                    trailing:
                    const Icon(Icons.verified, color: Colors.green),
                  ),

                  // Sign Out
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Sign Out"),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => Dialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.logout,
                                      size: 32, color: AppTheme.orange),
                                ),
                                const SizedBox(height: 16),
                                Text('Sign Out',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                Text('Are you sure you want to sign out?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets
                                              .symmetric(vertical: 12),
                                          side: const BorderSide(
                                              color: AppTheme.mediumGray),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.orange,
                                          padding: const EdgeInsets
                                              .symmetric(vertical: 12),
                                        ),
                                        child: const Text('Sign Out',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (confirm == true) {
                        await ref.read(authServiceProvider).signOut();
                      }
                    },
                  ),

                  // Delete Account (deferred 30-day flow)
                  ListTile(
                    leading:
                    const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text("Delete Account",
                        style: TextStyle(color: Colors.red)),
                    subtitle:
                    const Text("Request permanent deletion of your data"),
                    onTap: () =>
                        _showDeletionRequestSheet(context, ref, user.email),
                  ),
                ],
              );
            },
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text("Loading..."),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.error),
              title: Text("Error loading account"),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── Recording Settings ───────────────────────────────────────────
          const Text(
            "Recording Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text("Auto Gain Control"),
            subtitle: const Text("Automatically adjust microphone gain"),
            value: settings.autoGainControl,
            onChanged: (v) =>
                updateSettings(settings.copyWith(autoGainControl: v)),
          ),
          SwitchListTile(
            title: const Text("Noise Suppression"),
            subtitle: const Text("Reduce background noise"),
            value: settings.noiseSuppression,
            onChanged: (v) =>
                updateSettings(settings.copyWith(noiseSuppression: v)),
          ),
          SwitchListTile(
            title: const Text("Echo Cancellation"),
            subtitle: const Text("Minimize echo in recordings"),
            value: settings.echoCancellation,
            onChanged: (v) =>
                updateSettings(settings.copyWith(echoCancellation: v)),
          ),

          // Beep toggle — new in v1.3.0
          SwitchListTile(
            title: const Text("Recording Beeps"),
            subtitle: const Text(
              "Play a tone before and after each recording",
            ),
            secondary: const Icon(Icons.notifications_active_outlined),
            value: settings.enableBeeps,
            onChanged: (v) =>
                updateSettings(settings.copyWith(enableBeeps: v)),
          ),

          ListTile(
            title: const Text("Recording Device"),
            subtitle: const Text("Choose input source"),
            trailing: DropdownButton<String>(
              value: settings.device,
              items: const [
                DropdownMenuItem(
                    value: "Default Microphone",
                    child: Text("Default Microphone")),
                DropdownMenuItem(
                    value: "External Mic", child: Text("External Mic")),
              ],
              onChanged: (v) => updateSettings(settings.copyWith(device: v!)),
            ),
          ),
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
          SwitchListTile(
            title: const Text("Show Live Waveform"),
            subtitle:
            const Text("Display real-time waveform during recording"),
            value: settings.showWaveform,
            inactiveTrackColor: Colors.grey,
            onChanged: (v) =>
                updateSettings(settings.copyWith(showWaveform: v)),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── App Settings ─────────────────────────────────────────────────
          const Text(
            "App Settings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ListTile(
            title: const Text("Theme"),
            subtitle: const Text("Choose app theme mode"),
            trailing: DropdownButton<String>(
              value: settings.themeMode,
              items: const [
                DropdownMenuItem(
                    value: "System", child: Text("System Default")),
                DropdownMenuItem(value: "Light", child: Text("Light")),
                DropdownMenuItem(value: "Dark", child: Text("Dark")),
              ],
              onChanged: (v) =>
                  updateSettings(settings.copyWith(themeMode: v!)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text("Reset All Settings"),
            subtitle: const Text("Restore default preferences"),
            onTap: () => notifier.reset(),
          ),
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: const Text("Rate This App"),
            subtitle: const Text("Tell others what you think!"),
            onTap: () async => RatingService.requestReview(),
          ),
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

  // ── Deletion request bottom sheet ──────────────────────────────────────────
  //
  // This does NOT call currentUser.delete() directly because:
  //   1. It only removes the Auth record — Firestore + Storage are untouched.
  //   2. It throws requires-recent-login for old sessions.
  // Instead, a deletion_requests/{uid} document is written to Firestore and
  // the user is signed out. You process it manually within 30 days.

  Future<void> _showDeletionRequestSheet(
      BuildContext context,
      WidgetRef ref,
      String? email,
      ) async {
    final reasonController = TextEditingController();
    bool submitting = false;

    final reasons = [
      'I no longer use the app',
      'Privacy concerns',
      'Switching to another app',
      'App not working as expected',
      'Other',
    ];
    String selectedReason = reasons.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.mediumGray,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title + icon
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_forever,
                              color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Account',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Text(
                                'Permanent — cannot be undone',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // What will be deleted
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'The following will be permanently deleted:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          for (final item in [
                            'Your Firebase account & sign-in credentials',
                            'All recording metadata & transcripts in the cloud',
                            'All backed-up audio files in cloud storage',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.remove_circle_outline,
                                      size: 16, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(item,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 16),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: AppTheme.teal),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Local recordings on this device are NOT deleted.',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.teal),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Timeline notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.orange.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule,
                              color: AppTheme.orange, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your data will be deleted within 30 days of your request.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account email (read-only)
                    if (email != null) ...[
                      Text('Account',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumGray.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(email,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Reason dropdown
                    Text('Reason (optional)',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      items: reasons
                          .map((r) => DropdownMenuItem(
                          value: r, child: Text(r, style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedReason = v!),
                    ),
                    if (selectedReason == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Tell us more (optional)…',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                  color: AppTheme.mediumGray),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                              setSheetState(() => submitting = true);
                              try {
                                final fullReason =
                                selectedReason == 'Other' &&
                                    reasonController
                                        .text
                                        .trim()
                                        .isNotEmpty
                                    ? reasonController.text.trim()
                                    : selectedReason;

                                await ref
                                    .read(authServiceProvider)
                                    .submitDeletionRequest(
                                    reason: fullReason);

                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                  _showDeletionConfirmation(context);
                                }
                              } catch (e) {
                                setSheetState(
                                        () => submitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to submit: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: submitting
                                ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                                : const Text(
                              'Submit Request',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeletionConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppTheme.teal, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Request Submitted',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your deletion request has been received. '
                    'Your account and all associated cloud data will be '
                    'permanently deleted within 30 days.\n\n'
                    'You have been signed out.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}