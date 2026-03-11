// lib/widgets/expandable_recording_card.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:vocal_memo/providers/auth_provider.dart';
import 'package:vocal_memo/screens/transcript_viewer_screen.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import '../providers/transcription_provider.dart';
import '../screens/trim_screen.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../providers/recording_provider.dart';
import '../providers/playback_provider.dart';
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
  PlayerController? _waveformController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recording.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _waveformController?.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);

    if (_isExpanded) {
      // Initialize waveform controller and load audio
      _initializeWaveform();
      ref.read(playbackProvider.notifier).load(widget.recording.filePath);
    } else {
      // Clean up
      ref.read(playbackProvider.notifier).stop();
      _waveformController?.dispose();
      _waveformController = null;
      _isEditingTitle = false;
    }
  }

  void _initializeWaveform() async {
    try {
      _waveformController = PlayerController();
      await _waveformController!.preparePlayer(
        path: widget.recording.filePath,
        shouldExtractWaveform: true,
        noOfSamples: 100,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing waveform: $e');
      }
    }
  }

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
      if (kDebugMode) {
        print('Error sharing: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share recording')),
        );
      }
    }
  }

  Future<void> _transcribeRecording() async {
    final canTranscribe = ref.read(canTranscribeProvider);
    final isAuthenticated = ref.read(authStateProvider).value != null;

    // Check 1-minute limit for unregistered users
    if (!isAuthenticated && widget.recording.duration.inSeconds > 60) {
      await FeatureGateDialog.show(
        context,
        title: 'Transcription Limit',
        message: 'Free users can only transcribe recordings up to 1 minute long.',
        benefits: [
          'Unlimited transcription length',
          'Better AI model (Gemini 2.5)',
          'Cloud backup & sync',
          'Audio trimming tools',
        ],
      );
      return;
    }

    // Check if user can transcribe (registered users only)
    if (!canTranscribe) {
      await FeatureGateDialog.show(
        context,
        title: 'Transcription Requires Account',
        message: 'Sign up for free to transcribe your recordings with AI.',
        benefits: [
          'AI transcription with Gemini',
          'Cloud backup & sync',
          'Audio trimming tools',
          'Cross-device access',
        ],
      );
      return;
    }

    // Check rate limit for registered users
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
      // Increment usage count
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

      // Refresh usage provider to update badge
      ref.invalidate(dailyUsageProvider);

      // Show loading indicator
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
                Text('Transcribing audio...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Trigger transcription
      await ref.read(transcriptionNotifierProvider(widget.recording.id).notifier)
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
    final playbackState = ref.watch(playbackProvider);
    final isCurrentlyPlaying =
        playbackState.currentFilePath == widget.recording.filePath;
    final transcriptionState = ref.watch(
      transcriptionNotifierProvider(widget.recording.id),
    );

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
          GestureDetector(
            onTap: _isEditingTitle ? null : _toggleExpanded,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isExpanded
                        ? Icons.arrow_drop_down_rounded
                        : Icons.play_arrow_rounded,
                    color: AppTheme.teal,
                    size: _isExpanded ? 40 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _isEditingTitle
                                ? TextField(
                                    controller: _titleController,
                                    autofocus: true,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _saveTitle(),
                                  )
                                : GestureDetector(
                                    onTap: _startEditingTitle,
                                    child: Row(
                                      children: [
                                        Text(
                                          widget.recording.displayTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 12),
                                        if (_isExpanded)
                                          Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: AppTheme.teal,
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          if (_isEditingTitle)
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                size: 24,
                                color: AppTheme.teal,
                              ),
                              onPressed: _saveTitle,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          if (widget.recording.isPinned && !_isEditingTitle)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.push_pin,
                                size: 14,
                                color: AppTheme.orange,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.recording.formattedDuration,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.recording.formattedTime,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (transcriptionState.isTranscribing) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.teal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  color: widget.recording.isFavorite
                      ? AppTheme.orange
                      : AppTheme.mediumGray,
                  onPressed: () {
                    ref
                        .read(recordingProvider.notifier)
                        .toggleFavorite(widget.recording.id);
                  },
                  icon: Icon(
                    widget.recording.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const SizedBox(height: 16),

            // Waveform visualization (conditionally shown based on settings)
            Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(settingsProvider);

                if (!settings.showWaveform) {
                  // If waveform is disabled, show placeholder
                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Waveform disabled in settings',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                if (_waveformController != null) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTapDown: (details) async {
                            // Calculate position based on tap
                            final double tapPosition = details.localPosition.dx;
                            final double width = constraints.maxWidth;
                            final double percentage = (tapPosition / width)
                                .clamp(0.0, 1.0);

                            // Calculate seek position
                            final Duration seekPosition = Duration(
                              milliseconds:
                                  (widget.recording.duration.inMilliseconds *
                                          percentage)
                                      .toInt(),
                            );

                            // Seek both the waveform and playback
                            await _waveformController?.seekTo(
                              seekPosition.inMilliseconds,
                            );
                            await ref
                                .read(playbackProvider.notifier)
                                .seek(seekPosition);
                          },
                          child: AudioFileWaveforms(
                            size: Size(constraints.maxWidth, 80),
                            playerController: _waveformController!,
                            waveformType: WaveformType.fitWidth,
                            playerWaveStyle: PlayerWaveStyle(
                              fixedWaveColor: AppTheme.teal.withValues(
                                alpha: 0.3,
                              ),
                              liveWaveColor: AppTheme.teal,
                              spacing: 6,
                              waveThickness: 3,
                              showSeekLine: true,
                              seekLineColor: AppTheme.orange,
                              seekLineThickness: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.teal),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 8),

            // Position display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCurrentlyPlaying
                        ? _formatDuration(playbackState.position)
                        : '00:00',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.displaySmall?.color,
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

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded),
                  color: AppTheme.teal,
                  iconSize: 28,
                  onPressed: () =>
                      ref.read(playbackProvider.notifier).skipBackward(),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppTheme.orange,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isCurrentlyPlaying && playbackState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (isCurrentlyPlaying) {
                        await ref
                            .read(playbackProvider.notifier)
                            .togglePlayPause();
                      } else {
                        await ref
                            .read(playbackProvider.notifier)
                            .load(widget.recording.filePath);
                        await _waveformController?.startPlayer();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded),
                  color: AppTheme.teal,
                  iconSize: 28,
                  onPressed: () =>
                      ref.read(playbackProvider.notifier).skipForward(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Speed selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1.0, 1.5, 2.0].map((speed) {
                final label = speed == speed.toInt()
                    ? '${speed.toInt()}x'
                    : '${speed}x';
                final isSelected =
                    isCurrentlyPlaying && playbackState.playbackSpeed == speed;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    checkmarkColor: Colors.white,
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && isCurrentlyPlaying) {
                        ref
                            .read(playbackProvider.notifier)
                            .setPlaybackSpeed(speed);
                      }
                    },
                    selectedColor: AppTheme.teal,
                    backgroundColor: Theme.of(context).cardColor,
                    side: BorderSide(
                      color: isSelected ? AppTheme.teal : AppTheme.mediumGray,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Transcript display with preview
            if (widget.recording.transcript != null &&
                widget.recording.transcript!.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TranscriptViewerScreen(recording: widget.recording),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.text_fields,
                            size: 16,
                            color: AppTheme.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Transcript',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppTheme.teal.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.recording.displayTranscript,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.recording.displayTranscript.split('\n').length > 4 ||
                          widget.recording.displayTranscript.length > 200)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tap to view full transcript',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            if (widget.recording.transcript != null &&
                widget.recording.transcript!.isNotEmpty)
              const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.content_cut_rounded),
                  color: AppTheme.teal,
                  onPressed: () {
                    // Check if yser can trim
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
                        builder: (context) =>
                            TrimScreen(recording: widget.recording),
                      ),
                    );
                  },
                  tooltip: 'Trim',
                ),
                // Transcribe button with rate limit badge
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
                          backgroundColor: remaining > 3
                              ? AppTheme.teal
                              : AppTheme.orange,
                          child: IconButton(
                            icon: transcriptionState.isTranscribing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.teal,
                                    ),
                                  )
                                : const Icon(Icons.text_fields_rounded),
                            color: widget.recording.transcript != null
                                ? AppTheme.orange
                                : AppTheme.teal,
                            onPressed: () {
                              transcriptionState.isTranscribing
                                  ? null
                                  : canTranscribe
                                  ? _transcribeRecording()
                                  : FeatureGateDialog.show(
                                      context,
                                      title: 'Sign in required',
                                      message:
                                          'Sign in is required to use the transcription feature.',
                                    );
                            },
                            tooltip: widget.recording.transcript != null
                                ? 'Re-transcribe'
                                : 'Transcribe',
                          ),
                        );
                      },
                      loading: () => IconButton(
                        icon: const Icon(Icons.text_fields_rounded),
                        color: AppTheme.teal,
                        onPressed: _transcribeRecording,
                        tooltip: 'Transcribe',
                      ),
                      error: (_, __) => IconButton(
                        icon: const Icon(Icons.text_fields_rounded),
                        color: AppTheme.teal,
                        onPressed: _transcribeRecording,
                        tooltip: 'Transcribe',
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    widget.recording.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  color: widget.recording.isFavorite
                      ? AppTheme.orange
                      : AppTheme.mediumGray,
                  onPressed: () {
                    ref
                        .read(recordingProvider.notifier)
                        .toggleFavorite(widget.recording.id);
                  },
                  tooltip: 'Favorite',
                ),
                IconButton(
                  icon: Icon(
                    widget.recording.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                  ),
                  color: widget.recording.isPinned
                      ? AppTheme.orange
                      : AppTheme.mediumGray,
                  onPressed: () {
                    ref
                        .read(recordingProvider.notifier)
                        .togglePin(widget.recording.id);
                  },
                  tooltip: 'Pin',
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  color: AppTheme.teal,
                  onPressed: _shareRecording,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  onPressed: () {
                    _showDeleteConfirmation(context);
                  },
                  tooltip: 'Delete',
                ),
              ],
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
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This action cannot be undone.',
                            style: TextStyle(fontSize: 13, color: AppTheme.orange),
                          ),
                        ),
                      ]
                    )
                  ]
                )
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
