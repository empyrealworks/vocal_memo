// lib/widgets/speed_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/playback_provider.dart';

class SpeedSelector extends ConsumerWidget {
  final List<double> speeds;

  const SpeedSelector({
    super.key,
    this.speeds = const [1.0, 1.5, 2.0],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSpeed = ref.watch(playbackProvider).playbackSpeed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: speeds.map((speed) {
        final label = speed == speed.toInt()
            ? '${speed.toInt()}x'
            : '${speed}x';
        final isSelected = currentSpeed == speed;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref.read(playbackProvider.notifier).setPlaybackSpeed(speed);
              }
            },
            selectedColor: AppTheme.teal,
            backgroundColor: AppTheme.lightGray,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.darkText,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}