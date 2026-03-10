// lib/services/rate_limit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class RateLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  RateLimitService(this._authService);

  static const int DAILY_LIMIT = 10;

  String? get _userId => _authService.currentUser?.uid;

  /// Get user's transcription usage for today
  Future<Map<String, dynamic>> getTodayUsage() async {
    if (_userId == null) {
      return {'count': 0, 'limit': 0, 'remaining': 0, 'canTranscribe': false};
    }

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('usage')
          .doc('transcriptions')
          .get();

      if (!doc.exists) {
        return {
          'count': 0,
          'limit': DAILY_LIMIT,
          'remaining': DAILY_LIMIT,
          'canTranscribe': true,
          'resetAt': _getNextResetTime(),
        };
      }

      final data = doc.data()!;
      final lastReset = (data['lastReset'] as Timestamp?)?.toDate();
      final count = data['count'] as int? ?? 0;

      // Check if we need to reset (new day)
      if (lastReset == null || lastReset.isBefore(startOfDay)) {
        // Reset count for new day
        await _resetDailyCount();
        return {
          'count': 0,
          'limit': DAILY_LIMIT,
          'remaining': DAILY_LIMIT,
          'canTranscribe': true,
          'resetAt': _getNextResetTime(),
        };
      }

      final remaining = DAILY_LIMIT - count;
      return {
        'count': count,
        'limit': DAILY_LIMIT,
        'remaining': remaining,
        'canTranscribe': remaining > 0,
        'resetAt': _getNextResetTime(),
      };
    } catch (e) {
      print('Error getting usage: $e');
      return {
        'count': 0,
        'limit': DAILY_LIMIT,
        'remaining': DAILY_LIMIT,
        'canTranscribe': true,
      };
    }
  }

  /// Increment transcription count
  Future<bool> incrementUsage() async {
    if (_userId == null) return false;

    try {
      final usage = await getTodayUsage();
      if (!(usage['canTranscribe'] as bool)) {
        return false; // Limit reached
      }

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('usage')
          .doc('transcriptions')
          .set({
        'count': FieldValue.increment(1),
        'lastReset': Timestamp.now(),
        'lastUsed': Timestamp.now(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error incrementing usage: $e');
      return false;
    }
  }

  /// Reset daily count (called automatically on new day)
  Future<void> _resetDailyCount() async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('usage')
          .doc('transcriptions')
          .set({
        'count': 0,
        'lastReset': Timestamp.now(),
      });
    } catch (e) {
      print('Error resetting count: $e');
    }
  }

  /// Get time until next reset (midnight)
  DateTime _getNextResetTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow;
  }

  /// Get formatted time until reset
  String getTimeUntilReset() {
    final now = DateTime.now();
    final reset = _getNextResetTime();
    final diff = reset.difference(now);

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }
}