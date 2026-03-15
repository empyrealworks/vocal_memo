// lib/services/sync_queue_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Represents a single pending cloud-sync operation that was deferred because
/// the device was offline.
class PendingSyncJob {
  final String recordingId;
  final String filePath;
  final DateTime enqueuedAt;

  PendingSyncJob({
    required this.recordingId,
    required this.filePath,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
    'recordingId': recordingId,
    'filePath': filePath,
    'enqueuedAt': enqueuedAt.toIso8601String(),
  };

  factory PendingSyncJob.fromJson(Map<String, dynamic> json) => PendingSyncJob(
    recordingId: json['recordingId'] as String,
    filePath: json['filePath'] as String,
    enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
  );
}

/// Persists pending upload jobs to Hive so they survive app restarts.
///
/// Typical flow:
///   1. Device goes offline while user tries to back up a recording.
///   2. [enqueue] adds a [PendingSyncJob] to the Hive box.
///   3. App detects reconnection → calls [drain] to process all pending jobs.
///   4. Each successfully processed job is removed from the queue.
class SyncQueueService {
  static const _boxName = 'sync_queue';
  late Box<String> _box;

  bool _isOpen = false;

  // ─── Lifecycle ────────────────────────────────────────────────

  Future<void> init() async {
    if (_isOpen) return;
    _box = await Hive.openBox<String>(_boxName);
    _isOpen = true;
    debugPrint('📦 SyncQueueService: ${_box.length} pending job(s) loaded');
  }

  // ─── Public API ───────────────────────────────────────────────

  int get pendingCount => _isOpen ? _box.length : 0;

  bool get hasPending => pendingCount > 0;

  /// Adds a recording upload job to the queue.
  ///
  /// Safe to call even if a job for the same [recordingId] already exists —
  /// the existing entry is overwritten with the latest [filePath].
  Future<void> enqueue(PendingSyncJob job) async {
    await _ensureOpen();
    await _box.put(job.recordingId, jsonEncode(job.toJson()));
    debugPrint(
        '📥 SyncQueue: enqueued upload for ${job.recordingId} (total: ${_box.length})');
  }

  /// Returns all pending jobs without removing them.
  List<PendingSyncJob> peekAll() {
    if (!_isOpen) return [];
    return _box.values
        .map((raw) {
      try {
        return PendingSyncJob.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<PendingSyncJob>()
        .toList();
  }

  /// Removes a successfully processed job from the queue.
  Future<void> remove(String recordingId) async {
    await _ensureOpen();
    await _box.delete(recordingId);
  }

  /// Removes all jobs from the queue (e.g. on sign-out).
  Future<void> clear() async {
    await _ensureOpen();
    await _box.clear();
  }

  // ─── Private helpers ──────────────────────────────────────────

  Future<void> _ensureOpen() async {
    if (!_isOpen) await init();
  }
}