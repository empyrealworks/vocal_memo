import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/trim_segment.dart';
import '../../utils/time_formatter.dart';

class SegmentListItem extends StatelessWidget {
  final int index;
  final TrimSegment segment;

  const SegmentListItem({
    super.key,
    required this.index,
    required this.segment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.teal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${TimeFormatter.format(segment.start)} → ${TimeFormatter.format(segment.end)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Duration: ${TimeFormatter.format(segment.duration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.darkText.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}