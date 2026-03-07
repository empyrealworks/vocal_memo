import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../models/trim_segment.dart';
import '../providers/recording_provider.dart';
import '../providers/playback_provider.dart';
import '../services/audio_editor_service.dart';
import '../widgets/playback_controls.dart';
import '../widgets/trim_widgets/info_row.dart';
import '../widgets/trim_widgets/segment_list_item.dart';
import '../widgets/trim_widgets/multi_segment_timeline_painter.dart';
import '../utils/time_formatter.dart';

class TrimScreen extends ConsumerStatefulWidget {
  final Recording recording;

  const TrimScreen({Key? key, required this.recording}) : super(key: key);

  @override
  ConsumerState<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends ConsumerState<TrimScreen> {
  late Duration _startTime;
  late Duration _endTime;
  final _editorService = AudioEditorService();
  bool _isSaving = false;
  bool _isDetectingSilence = false;
  late PlaybackNotifier providerNotifier = ref.read(playbackProvider.notifier);

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

    // Load audio for playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      providerNotifier.load(widget.recording.filePath);
    });
  }

  @override
  void dispose() {
    providerNotifier.stop();
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
      print('Error auto-trimming: $e');
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
      print('Error saving trimmed audio: $e');
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

                  // Playback controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview Audio',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const PlaybackControls(),
                      ],
                    ),
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
                            foregroundColor: AppTheme.darkText,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Selection info
                  if (_startTime < _endTime)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cut, color: AppTheme.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selection: ${TimeFormatter.format(_startTime)} → ${TimeFormatter.format(_endTime)} (${TimeFormatter.format(_endTime - _startTime)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_startTime < _endTime) const SizedBox(height: 16),

                  // Sliders
                  Text(
                    'Selection Start: ${TimeFormatter.format(_startTime)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _startTime.inMilliseconds.toDouble(),
                    min: 0,
                    max: widget.recording.duration.inMilliseconds.toDouble(),
                    activeColor: AppTheme.teal,
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
                  const SizedBox(height: 24),

                  Text(
                    'Selection End: ${TimeFormatter.format(_endTime)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _endTime.inMilliseconds.toDouble(),
                    min: 0,
                    max: widget.recording.duration.inMilliseconds.toDouble(),
                    activeColor: AppTheme.orange,
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
                  const SizedBox(height: 24),

                  // Timeline
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: MultiSegmentTimelinePainter(
                        keepSegments: _keepSegments,
                        currentSelection: (_startTime, _endTime),
                        totalDuration: widget.recording.duration,
                        currentPosition: playbackState.position,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0:00', style: Theme.of(context).textTheme.labelSmall),
                      Text(widget.recording.formattedDuration,
                          style: Theme.of(context).textTheme.labelSmall),
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
                            'Select unwanted sections and tap "Remove Selection" to cut them out. You can remove multiple sections before saving.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
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