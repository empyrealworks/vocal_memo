// lib/widgets/waveform_player_area.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

import '../../models/recording.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class WaveformPlayerArea extends ConsumerWidget {
  final PlayerController? controller;
  final Recording recording;

  const WaveformPlayerArea({
    super.key,
    required this.controller,
    required this.recording,
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
        final waveStyle = PlayerWaveStyle(
          fixedWaveColor: AppTheme.teal.withValues(alpha: 0.25),
          liveWaveColor: AppTheme.teal,
          spacing: 3,
          waveThickness: 2,
          showSeekLine: true,
          seekLineColor: AppTheme.orange,
          seekLineThickness: 2,
          scrollScale: 1.2,
        );

        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: recording.waveformData != null && recording.waveformData!.isNotEmpty
                ? AudioFileWaveforms(
                    size: Size(constraints.maxWidth, 88),
                    playerController: controller!,
                    waveformType: WaveformType.long,
                    waveformData: recording.waveformData!,
                    enableSeekGesture: true,
                    playerWaveStyle: waveStyle,
                  )
                : AudioFileWaveforms(
                    size: Size(constraints.maxWidth, 88),
                    playerController: controller!,
                    waveformType: WaveformType.long,
                    enableSeekGesture: true,
                    playerWaveStyle: waveStyle,
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
