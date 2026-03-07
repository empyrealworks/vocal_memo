// lib/widgets/expandable_recording_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../providers/transcription_provider.dart';
import '../screens/trim_screen.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../providers/recording_provider.dart';
import '../providers/playback_provider.dart';

class ExpandableRecordingCard extends ConsumerStatefulWidget {
  final Recording recording;

  const ExpandableRecordingCard({
    Key? key,
    required this.recording,
  }) : super(key: key);

  @override
  ConsumerState<ExpandableRecordingCard> createState() =>
      _ExpandableRecordingCardState();
}

class _ExpandableRecordingCardState
    extends ConsumerState<ExpandableRecordingCard> {
  bool _isExpanded = false;
  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recording.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      // Load audio when expanded
      ref.read(playbackProvider.notifier).load(widget.recording.filePath);
    } else {
      // Stop when collapsed
      ref.read(playbackProvider.notifier).stop();
      _isEditingTitle = false;
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
      ref.read(recordingProvider.notifier).updateRecording(
        widget.recording.copyWith(title: newTitle),
      );
    }
    setState(() => _isEditingTitle = false);
  }

  Future<void> _shareRecording() async {
    try {
      final file = File(widget.recording.filePath);
      if (await file.exists()) {
        SharePlus.instance.share(ShareParams(
          text: 'Recording: ${widget.recording.displayTitle}',
          files: [XFile(widget.recording.filePath)]
        ));
      }
    } catch (e) {
      print('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share recording')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackProvider);
    final isCurrentlyPlaying = playbackState.currentFilePath == widget.recording.filePath;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
                    _isExpanded ? Icons.arrow_drop_down_rounded : Icons.play_arrow_rounded,
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
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText,
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
                              child: Text(
                                widget.recording.displayTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_isEditingTitle)
                            IconButton(
                              icon: const Icon(Icons.check, size: 18),
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  widget.recording.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: widget.recording.isFavorite
                      ? AppTheme.orange
                      : AppTheme.mediumGray,
                  size: 20,
                ),
              ],
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const SizedBox(height: 16),

            // Progress slider - now works always
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: isCurrentlyPlaying
                        ? playbackState.progress.clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) {
                      // Always allow seeking
                      if (isCurrentlyPlaying) {
                        final newPosition = Duration(
                          milliseconds: (value *
                              playbackState.duration.inMilliseconds)
                              .toInt(),
                        );
                        ref.read(playbackProvider.notifier).seek(newPosition);
                      }
                    },
                    activeColor: AppTheme.teal,
                    inactiveColor: AppTheme.mediumGray,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCurrentlyPlaying
                            ? _formatDuration(playbackState.position)
                            : '00:00',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkText,
                        ),
                      ),
                      Text(
                        widget.recording.formattedDuration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 10s backward
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded),
                  color: AppTheme.teal,
                  iconSize: 28,
                  onPressed: () =>
                      ref.read(playbackProvider.notifier).skipBackward(),
                ),
                const SizedBox(width: 24),
                // Play/Pause
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
                    onPressed: isCurrentlyPlaying
                        ? () => ref
                        .read(playbackProvider.notifier)
                        .togglePlayPause()
                        : () => ref
                        .read(playbackProvider.notifier)
                        .load(widget.recording.filePath),
                  ),
                ),
                const SizedBox(width: 24),
                // 10s forward
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
                final label =
                speed == speed.toInt() ? '${speed.toInt()}x' : '${speed}x';
                final isSelected = isCurrentlyPlaying &&
                    playbackState.playbackSpeed == speed;

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
                    backgroundColor: AppTheme.lightGray,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkText,
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

            // Organization buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                IconButton(
                  icon: const Icon(Icons.content_cut_rounded),
                  color: AppTheme.teal,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrimScreen(recording: widget.recording),
                      ),
                    );
                  },
                  tooltip: 'Trim',
                ),
                IconButton(
                  icon: const Icon(Icons.text_fields_rounded),
                  color: widget.recording.transcript != null
                      ? AppTheme.orange
                      : AppTheme.mediumGray,
                  onPressed: () async {
                    // Transcribe the recording
                    final transcript = await ref
                        .read(transcriptionServiceProvider)
                        .transcribeFile(widget.recording.filePath);

                    if (transcript != null) {
                      ref.read(recordingProvider.notifier).updateRecording(
                        widget.recording.copyWith(transcript: transcript),
                      );
                    }
                  },
                  tooltip: 'Transcribe',
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
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  color: AppTheme.teal,
                  onPressed: _shareRecording,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                  onPressed: () {
                    _showDeleteConfirmation(context);
                  },
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(recordingProvider.notifier)
                  .deleteRecording(widget.recording.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
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