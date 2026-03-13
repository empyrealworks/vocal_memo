// lib/widgets/transport_controls.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TransportControls extends StatelessWidget {
  final bool isPlaying;
  final double currentSpeed;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;
  final ValueChanged<double> onSpeedChanged;

  const TransportControls({
    super.key,
    required this.isPlaying,
    required this.currentSpeed,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onSkipBackward,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Play/Pause & Skip Row ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              color: AppTheme.teal,
              iconSize: 28,
              onPressed: onSkipBackward,
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
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: onPlayPause,
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              color: AppTheme.teal,
              iconSize: 28,
              onPressed: onSkipForward,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Speed Selector Row ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [0.5, 1.0, 1.5, 2.0].map((speed) {
            final label = speed == speed.truncate().toDouble()
                ? '${speed.toInt()}x'
                : '${speed}x';
            final isSelected = currentSpeed == speed;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                checkmarkColor: Colors.white,
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) onSpeedChanged(speed);
                },
                selectedColor: AppTheme.teal,
                backgroundColor: Theme.of(context).cardColor,
                side: BorderSide(
                  color: isSelected ? AppTheme.teal : AppTheme.mediumGray,
                ),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}