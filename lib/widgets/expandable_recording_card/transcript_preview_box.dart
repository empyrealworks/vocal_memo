// lib/widgets/transcript_preview_box.dart
import 'package:flutter/material.dart';
import '../../models/recording.dart';
import '../../theme/app_theme.dart';
import '../../screens/transcript_viewer_screen.dart';

class TranscriptPreviewBox extends StatelessWidget {
  final Recording recording;

  const TranscriptPreviewBox({
    super.key,
    required this.recording,
  });

  @override
  Widget build(BuildContext context) {
    if (recording.transcript == null || recording.transcript!.isEmpty) {
      return const SizedBox.shrink(); // Don't take up space if empty
    }

    final transcriptText = recording.displayTranscript;
    final isLong = transcriptText.split('\n').length > 4 || transcriptText.length > 200;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TranscriptViewerScreen(recording: recording),
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                transcriptText,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (isLong)
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
    );
  }
}