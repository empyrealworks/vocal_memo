import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../providers/selection_provider.dart';
import '../providers/recording_provider.dart';
import '../theme/app_theme.dart';
import 'custom_dialog.dart';

class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectionProvider);
    final count = selectedIds.length;

    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(selectionProvider.notifier).clear(),
            ),
            const SizedBox(width: 8),
            Text(
              '$count selected',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppTheme.teal),
              onPressed: () => _shareSelected(context, ref, selectedIds),
              tooltip: 'Share selected',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.orange),
              onPressed: () => _deleteSelected(context, ref, selectedIds),
              tooltip: 'Delete selected',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSelected(BuildContext context, WidgetRef ref, Set<String> ids) async {
    final recordings = ref.read(recordingProvider);
    final selectedRecordings = recordings.where((r) => ids.contains(r.id)).toList();
    
    final files = <XFile>[];
    for (final r in selectedRecordings) {
      if (await File(r.filePath).exists()) {
        files.add(XFile(r.filePath));
      }
    }

    if (files.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(
         files: files,
        subject: 'Sharing ${files.length} recordings from Vocal Memo',
      )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local audio files found to share')),
      );
    }
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref, Set<String> ids) async {
    CustomDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete Recordings',
      message: 'Are you sure you want to delete ${ids.length} recordings?',
      isDestructive: true,
      confirmText: 'Delete All',
      onConfirm: () {
        for (final id in ids) {
          ref.read(recordingProvider.notifier).deleteRecording(id).ignore();
        }
        ref.read(selectionProvider.notifier).clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${ids.length} recordings')),
        );
      },
    );
  }
}
