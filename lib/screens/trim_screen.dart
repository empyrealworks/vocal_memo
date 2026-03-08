// lib/screens/trim_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../models/trim_segment.dart';
import '../providers/recording_provider.dart';
import '../providers/playback_provider.dart';
import '../services/audio_editor_service.dart';
import '../widgets/trim_widgets/info_row.dart';
import '../widgets/trim_widgets/segment_list_item.dart';
import '../utils/time_formatter.dart';

class TrimScreen extends ConsumerStatefulWidget {
  final Recording recording;

  const TrimScreen({super.key, required this.recording});

  @override
  ConsumerState<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends ConsumerState<TrimScreen> {
  late Duration _startTime;
  late Duration _endTime;
  final _editorService = AudioEditorService();
  bool _isSaving = false;
  bool _isDetectingSilence = false;

  // Waveform controller for visualization
  PlayerController? _waveformController;

  // Keep track of segments to keep
  List<TrimSegment> _keepSegments = [];

  // History for undo
  final List<List<TrimSegment>> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _startTime = Duration.zero;
    _endTime = widget.recording.duration;

    // Initialize with full recording as one segment
    _keepSegments = [TrimSegment(start: Duration.zero, end: widget.recording.duration)];
    _saveToHistory();

    // Initialize waveform
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWaveform();
      ref.read(playbackProvider.notifier).load(widget.recording.filePath);
    });
  }

  Future<void> _initializeWaveform() async {
    try {
      _waveformController = PlayerController();
      await _waveformController!.preparePlayer(
        path: widget.recording.filePath,
        shouldExtractWaveform: true,
        noOfSamples: 200,
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

  @override
  void dispose() {
    ref.read(playbackProvider.notifier).stop();
    _waveformController?.dispose();
    super.dispose();
  }

  void _saveToHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(_keepSegments.map((s) => TrimSegment(start: s.start, end: s.end)).toList());
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _keepSegments = _history[_historyIndex].map((s) =>
            TrimSegment(start: s.start, end: s.end)).toList();
        if (_keepSegments.isNotEmpty) {
          _startTime = _keepSegments.first.start;
          _endTime = _keepSegments.first.end;
        }
      });
    }
  }

  void _reset() {
    setState(() {
      _keepSegments = [TrimSegment(start: Duration.zero, end: widget.recording.duration)];
      _startTime = Duration.zero;
      _endTime = widget.recording.duration;
      _saveToHistory();
    });
  }

  void _removeCurrentSelection() {
    if (_startTime >= _endTime) return;

    setState(() {
      final List<TrimSegment> newSegments = [];

      for (var segment in _keepSegments) {
        if (_endTime <= segment.start) {
          newSegments.add(segment);
        } else if (_startTime >= segment.end) {
          newSegments.add(segment);
        } else {
          if (_startTime > segment.start) {
            newSegments.add(TrimSegment(start: segment.start, end: _startTime));
          }
          if (_endTime < segment.end) {
            newSegments.add(TrimSegment(start: _endTime, end: segment.end));
          }
        }
      }

      _keepSegments = newSegments;

      if (_keepSegments.isNotEmpty) {
        _startTime = _keepSegments.first.start;
        _endTime = _keepSegments.first.end;
      } else {
        _startTime = Duration.zero;
        _endTime = Duration.zero;
      }

      _saveToHistory();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selection removed'),
        duration: Duration(seconds: 1),
        backgroundColor: AppTheme.orange,
      ),
    );
  }

  Duration _getTotalKeptDuration() {
    return _keepSegments.fold(Duration.zero, (sum, segment) => sum + segment.duration);
  }

  Future<void> _autoTrimSilence() async {
    setState(() => _isDetectingSilence = true);

    try {
      final silenceData = await _editorService.detectSilence(widget.recording.filePath);

      if (silenceData != null && silenceData['end'] != null) {
        setState(() {
          final trimmedStart = silenceData['start'] ?? Duration.zero;
          final trimmedEnd = silenceData['end'] ?? widget.recording.duration;

          _keepSegments = [TrimSegment(start: trimmedStart, end: trimmedEnd)];
          _startTime = trimmedStart;
          _endTime = trimmedEnd;
          _saveToHistory();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silence detected and trimmed'),
              backgroundColor: AppTheme.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not detect silence')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error auto-trimming: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingSilence = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving || _keepSegments.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final outputPath = await _editorService.applyMultipleTrims(
        inputPath: widget.recording.filePath,
        keepSegments: _keepSegments,
      );

      if (outputPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save trimmed recording')),
          );
        }
        return;
      }

      final trimmedRecording = Recording(
        id: const Uuid().v4(),
        fileName: outputPath.split('/').last,
        title: '${widget.recording.title ?? widget.recording.displayTitle} (Trimmed)',
        filePath: outputPath,
        createdAt: DateTime.now(),
        duration: _getTotalKeptDuration(),
      );

      await ref.read(recordingProvider.notifier).updateRecording(trimmedRecording);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trimmed recording saved successfully'),
            backgroundColor: AppTheme.teal,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving trimmed audio: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving trimmed recording')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keptDuration = _getTotalKeptDuration();
    final removedDuration = widget.recording.duration - keptDuration;
    final playbackState = ref.watch(playbackProvider);
    final canUndo = _historyIndex > 0;
    final hasSegments = _keepSegments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trim Recording'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? _undo : null,
            color: canUndo ? AppTheme.teal : Colors.grey,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            color: AppTheme.orange,
            tooltip: 'Reset',
          ),
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.teal,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: hasSegments ? _saveChanges : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: hasSegments ? AppTheme.teal : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        InfoRow(
                          label: 'Original Duration',
                          value: widget.recording.formattedDuration,
                        ),
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Kept Duration',
                          value: TimeFormatter.format(keptDuration),
                          valueColor: AppTheme.teal,
                        ),
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Removed',
                          value: TimeFormatter.format(removedDuration),
                          valueColor: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Segments',
                          value: '${_keepSegments.length}',
                          valueColor: AppTheme.orange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Interactive Waveform with Dual Handles
                  Text(
                    'Select Section to Remove',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.mediumGray),
                        ),
                        child: Stack(
                          children: [
                            // Waveform
                            if (_waveformController != null)
                              AudioFileWaveforms(
                                size: Size(constraints.maxWidth, 120),
                                playerController: _waveformController!,
                                waveformType: WaveformType.fitWidth,
                                playerWaveStyle: PlayerWaveStyle(
                                  fixedWaveColor: AppTheme.teal.withValues(alpha: 0.3),
                                  liveWaveColor: AppTheme.teal,
                                  spacing: 6,
                                  waveThickness: 3,
                                  showSeekLine: false,
                                ),
                              )
                            else
                              const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.teal,
                                ),
                              ),

                            // Selection overlay
                            CustomPaint(
                              painter: TrimSelectionPainter(
                                startTime: _startTime,
                                endTime: _endTime,
                                totalDuration: widget.recording.duration,
                                currentPosition: playbackState.position,
                              ),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Dual slider handles
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start: ${TimeFormatter.format(_startTime)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _startTime.inMilliseconds.toDouble(),
                              min: 0,
                              max: widget.recording.duration.inMilliseconds.toDouble(),
                              activeColor: AppTheme.orange,
                              onChanged: (value) {
                                setState(() {
                                  _startTime = Duration(milliseconds: value.toInt());
                                  if (_startTime >= _endTime) {
                                    _endTime = _startTime + const Duration(seconds: 1);
                                    if (_endTime > widget.recording.duration) {
                                      _endTime = widget.recording.duration;
                                      _startTime = _endTime - const Duration(seconds: 1);
                                    }
                                  }
                                });
                              },
                              onChangeEnd: (value) {
                                ref.read(playbackProvider.notifier).seek(_startTime);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.teal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'End: ${TimeFormatter.format(_endTime)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _endTime.inMilliseconds.toDouble(),
                              min: 0,
                              max: widget.recording.duration.inMilliseconds.toDouble(),
                              activeColor: AppTheme.teal,
                              onChanged: (value) {
                                setState(() {
                                  _endTime = Duration(milliseconds: value.toInt());
                                  if (_endTime <= _startTime) {
                                    _startTime = _endTime - const Duration(seconds: 1);
                                    if (_startTime < Duration.zero) {
                                      _startTime = Duration.zero;
                                      _endTime = const Duration(seconds: 1);
                                    }
                                  }
                                });
                              },
                              onChangeEnd: (value) {
                                ref.read(playbackProvider.notifier).seek(_endTime);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_startTime < _endTime) ? _removeCurrentSelection : null,
                          icon: const Icon(Icons.content_cut),
                          label: const Text('Remove Selection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isDetectingSilence ? null : _autoTrimSilence,
                          icon: _isDetectingSilence
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.auto_fix_high),
                          label: const Text('Auto-Trim'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.teal, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Use the dual sliders to select unwanted sections, then tap "Remove Selection". You can remove multiple sections before saving.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Segment list
                  if (_keepSegments.length > 1) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Kept Segments (${_keepSegments.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_keepSegments.length, (index) {
                      return SegmentListItem(
                        index: index,
                        segment: _keepSegments[index],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for trim selection overlay
class TrimSelectionPainter extends CustomPainter {
  final Duration startTime;
  final Duration endTime;
  final Duration totalDuration;
  final Duration currentPosition;

  TrimSelectionPainter({
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Calculate positions
    final startX = (startTime.inMilliseconds / totalDuration.inMilliseconds) * size.width;
    final endX = (endTime.inMilliseconds / totalDuration.inMilliseconds) * size.width;

    // Draw selection overlay (area to remove)
    if (startX < endX) {
      paint.color = AppTheme.orange.withValues(alpha: 0.3);
      canvas.drawRect(
        Rect.fromLTWH(startX, 0, endX - startX, size.height),
        paint,
      );

      // Draw start handle
      paint.color = AppTheme.orange;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX - 3, 0, 6, size.height),
          const Radius.circular(3),
        ),
        paint,
      );

      // Draw end handle
      paint.color = AppTheme.teal;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(endX - 3, 0, 6, size.height),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    // Draw playback position
    final currentX = (currentPosition.inMilliseconds / totalDuration.inMilliseconds) * size.width;
    paint.color = Colors.white;
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(TrimSelectionPainter oldDelegate) =>
      oldDelegate.startTime != startTime ||
          oldDelegate.endTime != endTime ||
          oldDelegate.currentPosition != currentPosition;
}