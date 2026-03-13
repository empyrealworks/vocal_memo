// lib/widgets/expandable_recording_card.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:vocal_memo/providers/auth_provider.dart';
import 'package:vocal_memo/widgets/expandable_recording_card/recording_action_bar.dart';
import 'dart:io';
import '../providers/transcription_provider.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../providers/recording_provider.dart';
import '../providers/playback_provider.dart';
import 'expandable_recording_card/recording_card_header.dart';
import 'expandable_recording_card/transcript_preview_box.dart';
import 'expandable_recording_card/transport_controls.dart';
import 'expandable_recording_card/waveform_player_area.dart';
import 'feature_gate_dialog.dart';

class ExpandableRecordingCard extends ConsumerStatefulWidget {
  final Recording recording;

  const ExpandableRecordingCard({super.key, required this.recording});

  @override
  ConsumerState<ExpandableRecordingCard> createState() =>
      _ExpandableRecordingCardState();
}

class _ExpandableRecordingCardState
    extends ConsumerState<ExpandableRecordingCard> {
  bool _isExpanded = false;
  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  // ── Playback state (all driven by PlayerController) ───────────────────────
  PlayerController? _waveformController;
  StreamSubscription<int>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _completionSub;

  int _currentPositionMs = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  // Backup state
  bool _isBackingUp = false;
  double _backupProgress = 0.0;
  String? _backupError;

  // First-expand feature hints
  bool _showCardHints = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recording.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cancelSubscriptions();
    _waveformController?.stopPlayer();
    _waveformController?.dispose();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _completionSub?.cancel();
    _positionSub = null;
    _playerStateSub = null;
    _completionSub = null;
  }

  // ── Expand / collapse ─────────────────────────────────────────────────────

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _initializeWaveform();
    } else {
      _collapseCleanup();
    }
  }

  void _collapseCleanup() {
    _cancelSubscriptions();
    _waveformController?.stopPlayer();
    _waveformController?.dispose();
    _waveformController = null;

    if (ref.read(activeCardPlayerProvider) == widget.recording.id) {
      ref.read(activeCardPlayerProvider.notifier).state = null;
    }

    setState(() {
      _isPlaying = false;
      _currentPositionMs = 0;
      _playbackSpeed = 1.0;
      _isEditingTitle = false;
    });
  }

  // ── Waveform / player initialisation ─────────────────────────────────────

  void _initializeWaveform() async {
    try {
      _waveformController = PlayerController();

      // Use medium update frequency — smooth position tick without hammering.
      _waveformController!.updateFrequency = UpdateFrequency.medium;

      // Position stream.
      _positionSub = _waveformController!.onCurrentDurationChanged.listen((ms) {
        if (mounted) setState(() => _currentPositionMs = ms);
      });

      // State stream — keep _isPlaying in sync.
      _playerStateSub = _waveformController!.onPlayerStateChanged.listen((
        state,
      ) {
        if (!mounted) return;
        setState(() => _isPlaying = state == PlayerState.playing);
      });

      // Completion — reset to start, release focus.
      _completionSub = _waveformController!.onCompletion.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _currentPositionMs = 0;
        });
        if (ref.read(activeCardPlayerProvider) == widget.recording.id) {
          ref.read(activeCardPlayerProvider.notifier).state = null;
        }
      });

      // WaveformType.long needs a density that makes the scrollable waveform
      // readable. 10 samples/second is ideal:
      //   1-min recording  →  600 samples  (rich detail)
      //   5-min recording  → 3 000 samples (still smooth, not squashed)
      //  60-min recording  → 36 000 samples (capped by plugin internally)
      await _waveformController!.preparePlayer(
        path: widget.recording.filePath,
        shouldExtractWaveform: true,
        noOfSamplesPerSecond: 10,
      );

      // Restore speed if the card was previously playing at a non-default rate.
      if (_playbackSpeed != 1.0) {
        await _waveformController!.setRate(_playbackSpeed);
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) print('Error initializing waveform: $e');
    }
  }

  // ── Title editing ─────────────────────────────────────────────────────────

  void _startEditingTitle() {
    if (_isExpanded) {
      setState(() {
        _isEditingTitle = true;
        _titleController.text = widget.recording.title ?? '';
      });
    }
  }

  void _saveTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.recording.title) {
      ref
          .read(recordingProvider.notifier)
          .updateRecording(widget.recording.copyWith(title: newTitle));
    }
    setState(() => _isEditingTitle = false);
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> _togglePlayPause() async {
    if (_waveformController == null) return;
    if (_isPlaying) {
      await _waveformController!.pausePlayer();
    } else {
      // Claim global audio focus — all other cards will pause.
      ref.read(activeCardPlayerProvider.notifier).state = widget.recording.id;
      await _waveformController!.startPlayer();
    }
  }

  Future<void> _seekTo(int ms) async {
    if (_waveformController == null) return;
    final clamped = ms.clamp(0, widget.recording.duration.inMilliseconds);
    await _waveformController!.seekTo(clamped);
    if (mounted) setState(() => _currentPositionMs = clamped);
  }

  Future<void> _skipForward() async => _seekTo(_currentPositionMs + 10000);
  Future<void> _skipBackward() async => _seekTo(_currentPositionMs - 10000);

  Future<void> _setSpeed(double speed) async {
    if (_waveformController == null) return;
    await _waveformController!.setRate(speed);
    setState(() => _playbackSpeed = speed);
  }

  Future<void> _backupRecording() async {
    if (_isBackingUp) return;

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.0;
      _backupError = null;
    });

    try {
      final downloadUrl = await ref
          .read(recordingProvider.notifier)
          .backupRecording(
            widget.recording,
            onProgress: (progress) {
              if (mounted) setState(() => _backupProgress = progress);
            },
          );

      if (mounted) {
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup complete ✓'),
              backgroundColor: AppTheme.teal,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() => _backupError = 'Backup failed');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backupError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupProgress = 0.0;
        });
      }
    }
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  Future<void> _shareRecording() async {
    try {
      final file = File(widget.recording.filePath);
      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(widget.recording.filePath)],
            text: 'Recording: ${widget.recording.displayTitle}',
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share recording')),
        );
      }
    }
  }

  // ── Transcription ─────────────────────────────────────────────────────────

  Future<void> _transcribeRecording() async {
    final canTranscribe = ref.read(canTranscribeProvider);
    final isAuthenticated = ref.read(authStateProvider).value != null;

    if (!isAuthenticated && widget.recording.duration.inSeconds > 60) {
      await FeatureGateDialog.show(
        context,
        title: 'Transcription Limit',
        message: 'Free users can only transcribe recordings up to 1 minute.',
        benefits: [
          'Unlimited transcription length',
          'Better AI model (Gemini 2.5)',
          'Cloud backup & sync',
          'Audio trimming tools',
        ],
      );
      return;
    }

    if (!canTranscribe) {
      await FeatureGateDialog.show(
        context,
        title: 'Transcription Requires Account',
        message: 'Sign up for free to transcribe recordings with AI.',
        benefits: [
          'AI transcription with Gemini',
          'Cloud backup & sync',
          'Audio trimming tools',
          'Cross-device access',
        ],
      );
      return;
    }

    final usage = await ref.read(dailyUsageProvider.future);
    if (!(usage['canTranscribe'] as bool)) {
      final resetTime = ref.read(rateLimitServiceProvider).getTimeUntilReset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily limit reached (10/day). Resets in $resetTime',
              style: TextStyle(
                color: AppTheme.lightGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      final rateLimitService = ref.read(rateLimitServiceProvider);
      final incremented = await rateLimitService.incrementUsage();
      if (!incremented) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not increment usage. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      ref.invalidate(dailyUsageProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Transcribing audio…'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      await ref
          .read(transcriptionNotifierProvider(widget.recording.id).notifier)
          .transcribe(widget.recording);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcription complete!'),
            backgroundColor: AppTheme.teal,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When another card claims focus, pause this one.
    ref.listen<String?>(activeCardPlayerProvider, (prev, next) {
      if (next != null &&
          next != widget.recording.id &&
          _isPlaying &&
          _waveformController != null) {
        _waveformController!.pausePlayer();
      }
    });

    final transcriptionState =
    ref.watch(transcriptionNotifierProvider(widget.recording.id));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded ? AppTheme.teal : AppTheme.mediumGray,
          width: _isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isExpanded ? 0.1 : 0.05),
            blurRadius: _isExpanded ? 8 : 4,
            offset: Offset(0, _isExpanded ? 4 : 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header (always visible)
          RecordingCardHeader(
            recording: widget.recording,
            isExpanded: _isExpanded,
            isEditingTitle: _isEditingTitle,
            titleController: _titleController,
            isTranscribing: transcriptionState.isTranscribing,
            onToggleExpand: _toggleExpanded,
            onStartEditingTitle: _startEditingTitle,
            onSaveTitle: _saveTitle,
          ),

          // Expanded content
          if (_isExpanded) ...[
            const SizedBox(height: 16),

            // Waveform Area
            WaveformPlayerArea(
              controller: _waveformController,
            ),

            const SizedBox(height: 8),

            // ── Position / duration labels ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: _currentPositionMs)),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.displaySmall?.color,
                    ),
                  ),
                  // Drag hint — only show when not playing.
                  if (!_isPlaying)
                    Text(
                      '← drag to seek →',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).textTheme.displaySmall?.color?.withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  Text(
                    widget.recording.formattedDuration,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.displaySmall?.color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Transport controls ─────────────────────────────────────
            TransportControls(
              isPlaying: _isPlaying,
              currentSpeed: _playbackSpeed,
              onPlayPause: _togglePlayPause,
              onSkipForward: _skipForward,
              onSkipBackward: _skipBackward,
              onSpeedChanged: _setSpeed,
            ),

            const SizedBox(height: 16),

            // ── Transcript preview ─────────────────────────────────────
            TranscriptPreviewBox(recording: widget.recording),

            if (widget.recording.transcript != null &&
                widget.recording.transcript!.isNotEmpty)
              const SizedBox(height: 16),

            // Feature hints strip (shown only on first-ever card expansion)
            if (_showCardHints) ...[
              _CardHintsStrip(
                onDismiss: () {
                  setState(() => _showCardHints = false);
                },
              ),
              const SizedBox(height: 8),
            ],

            // Action Bar
            RecordingActionBar(
              recording: widget.recording,
              isTranscribing: transcriptionState.isTranscribing,
              isBackingUp: _isBackingUp,
              backupProgress: _backupProgress,
              backupError: _backupError,
              onTranscribe: _transcribeRecording,
              onBackup: _backupRecording,
              onShare: _shareRecording,
              onDelete: () => _showDeleteConfirmation(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 32,
                  color: AppTheme.orange,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Delete Recording',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Are you sure you want to delete this recording?',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              // Warning!!!
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This action cannot be undone.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.mediumGray),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(recordingProvider.notifier)
                            .deleteRecording(widget.recording.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

// ─── Card feature hints strip ─────────────────────────────────────────────────

class _CardHintsStrip extends StatelessWidget {
  final VoidCallback onDismiss;

  const _CardHintsStrip({required this.onDismiss});

  static const _hints = [
    _HintItem(
      icon: Icons.content_cut_rounded,
      label: 'Trim',
      color: AppTheme.teal,
    ),
    _HintItem(
      icon: Icons.text_fields_rounded,
      label: 'Transcribe',
      color: AppTheme.teal,
    ),
    _HintItem(
      icon: Icons.cloud_upload_rounded,
      label: 'Backup',
      color: AppTheme.teal,
    ),
    _HintItem(icon: Icons.share_rounded, label: 'Share', color: AppTheme.teal),
    _HintItem(
      icon: Icons.delete_outline_rounded,
      label: 'Delete',
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: AppTheme.teal,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'What each button does',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, size: 14, color: AppTheme.teal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _hints
                .map(
                  (h) =>
                      _HintChip(icon: h.icon, label: h.label, color: h.color),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HintItem {
  final IconData icon;
  final String label;
  final Color color;
  const _HintItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
