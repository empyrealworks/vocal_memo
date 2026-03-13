// lib/widgets/recording_card_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/recording.dart';
import '../../theme/app_theme.dart';
import '../../providers/recording_provider.dart';

class RecordingCardHeader extends ConsumerWidget {
  final Recording recording;
  final bool isExpanded;
  final bool isEditingTitle;
  final TextEditingController titleController;
  final bool isTranscribing;
  final VoidCallback onToggleExpand;
  final VoidCallback onStartEditingTitle;
  final VoidCallback onSaveTitle;

  const RecordingCardHeader({
    super.key,
    required this.recording,
    required this.isExpanded,
    required this.isEditingTitle,
    required this.titleController,
    required this.isTranscribing,
    required this.onToggleExpand,
    required this.onStartEditingTitle,
    required this.onSaveTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isEditingTitle ? null : onToggleExpand,
      child: Row(
        children: [
          // ── Play / Expand Icon ──
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpanded
                  ? Icons.arrow_drop_down_rounded
                  : Icons.play_arrow_rounded,
              color: AppTheme.teal,
              size: isExpanded ? 40 : 24,
            ),
          ),
          const SizedBox(width: 12),

          // ── Title & Metadata Column ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: isEditingTitle
                          ? TextField(
                        controller: titleController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onSaveTitle(),
                      )
                          : GestureDetector(
                        onTap: onToggleExpand,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                recording.displayTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                                softWrap: true,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isExpanded)
                              GestureDetector(
                                onTap: onStartEditingTitle,
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: AppTheme.teal,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isEditingTitle)
                      IconButton(
                        icon: const Icon(
                          Icons.check,
                          size: 24,
                          color: AppTheme.teal,
                        ),
                        onPressed: onSaveTitle,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Duration, Date, and Transcription Spinner
                Row(
                  children: [
                    Text(
                      recording.formattedDuration,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      recording.formattedTime,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (isTranscribing) ...[
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

          // ── Favorite Button ──
          IconButton(
            color: recording.isFavorite ? AppTheme.orange : AppTheme.mediumGray,
            onPressed: () {
              ref.read(recordingProvider.notifier).toggleFavorite(recording.id);
            },
            icon: Icon(
              recording.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
            ),
          ),

          // ── Pin Button ──
          IconButton(
            icon: Icon(
              recording.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            color: recording.isPinned ? AppTheme.orange : AppTheme.mediumGray,
            onPressed: () {
              ref.read(recordingProvider.notifier).togglePin(recording.id);
            },
            tooltip: 'Pin',
          ),
        ],
      ),
    );
  }
}
