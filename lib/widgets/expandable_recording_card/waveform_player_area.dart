// lib/widgets/waveform_player_area.dart

// ── Scrollable waveform timeline ──────────────────────────
//
// WaveformType.long behaviour:
//   • The rendered waveform is wider than the widget.
//   • The seek line stays centred; the waveform scrolls left
//     as audio plays — exactly like a DAW timeline.
//   • Drag anywhere on the waveform to seek. The plugin
//     handles gestures internally, so no GestureDetector overlay.
//   • Completed portion (left of seek line) is rendered in
//     liveWaveColor; upcoming portion in fixedWaveColor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class WaveformPlayerArea extends ConsumerWidget {
  final PlayerController? controller;

  const WaveformPlayerArea({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (!settings.showWaveform) {
      return _waveformDisabledPlaceholder(context);
    }

    if (controller == null) {
      return _waveformLoadingPlaceholder();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AudioFileWaveforms(
              size: Size(constraints.maxWidth, 88),
              playerController: controller!,
              waveformType: WaveformType.long,
              enableSeekGesture: true,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: AppTheme.teal.withValues(alpha: 0.25),
                liveWaveColor: AppTheme.teal,
                spacing: 5,
                waveThickness: 4,
                showSeekLine: true,
                seekLineColor: AppTheme.orange,
                seekLineThickness: 2,
                scrollScale: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _waveformDisabledPlaceholder(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'Waveform disabled in settings',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _waveformLoadingPlaceholder() {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.teal),
      ),
    );
  }
}