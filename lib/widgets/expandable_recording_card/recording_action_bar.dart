// lib/widgets/recording_action_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recording.dart';
import '../../providers/auth_provider.dart';
import '../../screens/trim_screen.dart';
import '../../theme/app_theme.dart';
import '../feature_gate_dialog.dart';

class RecordingActionBar extends ConsumerWidget {
  final Recording recording;
  final bool isTranscribing;
  final bool isBackingUp;
  final double backupProgress;
  final String? backupError;
  final VoidCallback onTranscribe;
  final VoidCallback onBackup;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const RecordingActionBar({
    super.key,
    required this.recording,
    required this.isTranscribing,
    required this.isBackingUp,
    required this.backupProgress,
    this.backupError,
    required this.onTranscribe,
    required this.onBackup,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ── Trim Button ──
        IconButton(
          icon: const Icon(Icons.content_cut_rounded),
          color: AppTheme.teal,
          onPressed: () {
            final canTrim = ref.read(canTrimProvider);
            if (!canTrim) {
              FeatureGateDialog.show(
                context,
                title: 'Sign in required',
                message: 'Sign in is required to use the trim feature.',
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrimScreen(recording: recording),
              ),
            );
          },
          tooltip: 'Trim',
        ),

        // ── Transcribe Button with Badge ──
        Consumer(
          builder: (context, ref, child) {
            final usage = ref.watch(dailyUsageProvider);

            return usage.when(
              data: (data) {
                final remaining = data['remaining'] as int? ?? 0;
                final canTranscribe = ref.read(canTranscribeProvider);

                return Badge(
                  label: canTranscribe && remaining >= 0
                      ? Text('$remaining')
                      : null,
                  isLabelVisible: canTranscribe,
                  backgroundColor:
                  remaining > 3 ? AppTheme.teal : AppTheme.orange,
                  child: IconButton(
                    icon: isTranscribing
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.teal,
                      ),
                    )
                        : const Icon(Icons.text_fields_rounded),
                    color: recording.transcript != null
                        ? AppTheme.orange
                        : AppTheme.teal,
                    onPressed: () {
                      if (isTranscribing) return;
                      canTranscribe
                          ? onTranscribe()
                          : FeatureGateDialog.show(
                        context,
                        title: 'Sign in required',
                        message:
                        'Sign in is required to use the transcription feature.',
                      );
                    },
                    tooltip: recording.transcript != null
                        ? 'Re-transcribe'
                        : 'Transcribe',
                  ),
                );
              },
              loading: () => IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                color: AppTheme.teal,
                onPressed: onTranscribe,
                tooltip: 'Transcribe',
              ),
              error: (_, __) => IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                color: AppTheme.teal,
                onPressed: onTranscribe,
                tooltip: 'Transcribe',
              ),
            );
          },
        ),

        // ── Cloud Backup Button ──
        Consumer(
          builder: (context, ref, child) {
            final isAuthenticated = ref.watch(authStateProvider).value != null;
            if (!isAuthenticated) return const SizedBox.shrink();

            final isBackedUp = recording.isBackedUp;

            if (isBackingUp) {
              return Tooltip(
                message: 'Uploading… ${(backupProgress * 100).toStringAsFixed(0)}%',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      value: backupProgress > 0 ? backupProgress : null,
                      strokeWidth: 2,
                      color: AppTheme.teal,
                    ),
                  ),
                ),
              );
            }

            return IconButton(
              icon: Icon(
                isBackedUp
                    ? Icons.cloud_done_rounded
                    : (backupError != null
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_upload_rounded),
              ),
              color: isBackedUp
                  ? AppTheme.teal
                  : (backupError != null ? Colors.red : AppTheme.mediumGray),
              onPressed: onBackup,
              tooltip: isBackedUp
                  ? 'Backed up – tap to re-upload'
                  : (backupError != null
                  ? 'Backup failed – tap to retry'
                  : 'Back up to cloud'),
            );
          },
        ),

        // ── Share Button ──
        IconButton(
          icon: const Icon(Icons.share_rounded),
          color: AppTheme.teal,
          onPressed: onShare,
          tooltip: 'Share',
        ),

        // ── Delete Button ──
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          color: Colors.red,
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}