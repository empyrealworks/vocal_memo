// lib/screens/transcript_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/recording.dart';
import '../providers/recording_provider.dart';

/// Full-screen transcript viewer and editor
///
/// Features:
/// - View full transcript
/// - Edit transcript
/// - Copy to clipboard
/// - Save to text file
/// - Share transcript
class TranscriptViewerScreen extends ConsumerStatefulWidget {
  final Recording recording;

  const TranscriptViewerScreen({super.key, required this.recording});

  @override
  ConsumerState<TranscriptViewerScreen> createState() =>
      _TranscriptViewerScreenState();
}

class _TranscriptViewerScreenState
    extends ConsumerState<TranscriptViewerScreen> {
  late TextEditingController _textController;
  bool _isEditing = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.recording.transcript ?? '',
    );
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges && _textController.text != widget.recording.transcript) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveChanges() async {
    final newTranscript = _textController.text.trim();

    if (newTranscript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ref
          .read(recordingProvider.notifier)
          .updateRecording(
            widget.recording.copyWith(transcript: newTranscript),
          );

      setState(() {
        _hasChanges = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcript saved'),
            backgroundColor: AppTheme.teal,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final transcriptsDir = Directory('${directory.path}/transcripts');

      if (!await transcriptsDir.exists()) {
        await transcriptsDir.create(recursive: true);
      }

      final fileName = '${widget.recording.displayTitle}_transcript.txt';
      final file = File('${transcriptsDir.path}/$fileName');

      await file.writeAsString(_textController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: ${file.path}'),
            backgroundColor: AppTheme.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareTranscript() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _textController.text,
          subject: 'Transcript: ${widget.recording.displayTitle}',
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Do you want to discard your changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transcript'),
          actions: [
            if (_isEditing && _hasChanges)
              TextButton(
                onPressed: _saveChanges,
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: AppTheme.teal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
                onPressed: () => setState(() => _isEditing = !_isEditing),
                tooltip: _isEditing ? 'View Mode' : 'Edit Mode',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'copy':
                    _copyToClipboard();
                    break;
                  case 'save_file':
                    _saveToFile();
                    break;
                  case 'share':
                    _shareTranscript();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      SizedBox(width: 12),
                      Text('Copy to Clipboard'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'save_file',
                  child: Row(
                    children: [
                      Icon(Icons.save_alt, size: 20),
                      SizedBox(width: 12),
                      Text('Save as File'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 12),
                      Text('Share'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Recording info header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.teal.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recording.displayTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.recording.formattedTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.recording.formattedDuration,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '${_textController.text.length} characters',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Transcript editor/viewer
            Expanded(child: _isEditing ? _buildEditor() : _buildViewer()),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Edit your transcript...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.mediumGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.teal, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _textController.text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }
}
