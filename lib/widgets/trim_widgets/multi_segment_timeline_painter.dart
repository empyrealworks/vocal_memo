import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/trim_segment.dart';

class MultiSegmentTimelinePainter extends CustomPainter {
  final List<TrimSegment> keepSegments;
  final (Duration, Duration) currentSelection;
  final Duration totalDuration;
  final Duration currentPosition;

  MultiSegmentTimelinePainter({
    required this.keepSegments,
    required this.currentSelection,
    required this.totalDuration,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw full background (removed sections in red)
    paint.color = Colors.red.withValues(alpha: 0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw kept segments in teal
    paint.color = AppTheme.teal.withValues(alpha: 0.6);
    for (var segment in keepSegments) {
      final startX = (segment.start.inMilliseconds / totalDuration.inMilliseconds) * size.width;
      final endX = (segment.end.inMilliseconds / totalDuration.inMilliseconds) * size.width;
      canvas.drawRect(Rect.fromLTWH(startX, 0, endX - startX, size.height), paint);
    }

    // Draw current selection in orange overlay
    final selectionStart = currentSelection.$1;
    final selectionEnd = currentSelection.$2;
    if (selectionStart < selectionEnd) {
      paint.color = AppTheme.orange.withValues(alpha: 0.5);
      final startX = (selectionStart.inMilliseconds / totalDuration.inMilliseconds) * size.width;
      final endX = (selectionEnd.inMilliseconds / totalDuration.inMilliseconds) * size.width;
      canvas.drawRect(Rect.fromLTWH(startX, 0, endX - startX, size.height), paint);

      // Draw selection handles
      paint.color = AppTheme.orange;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX - 4, 0, 8, size.height),
          const Radius.circular(4),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(endX - 4, 0, 8, size.height),
          const Radius.circular(4),
        ),
        paint,
      );
    }

    // Draw playback position indicator
    final currentX = (currentPosition.inMilliseconds / totalDuration.inMilliseconds) * size.width;
    paint.color = Colors.white;
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height),
      paint,
    );

    // Draw segment separators
    paint.color = Colors.white.withValues(alpha: 0.8);
    paint.strokeWidth = 2;
    for (var segment in keepSegments) {
      final startX = (segment.start.inMilliseconds / totalDuration.inMilliseconds) * size.width;
      final endX = (segment.end.inMilliseconds / totalDuration.inMilliseconds) * size.width;

      if (startX > 0) {
        canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), paint);
      }
      if (endX < size.width) {
        canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(MultiSegmentTimelinePainter oldDelegate) =>
      oldDelegate.keepSegments != keepSegments ||
          oldDelegate.currentSelection != currentSelection ||
          oldDelegate.currentPosition != currentPosition;
}