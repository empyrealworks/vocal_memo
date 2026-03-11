// lib/services/storage_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recording.dart';

class  StorageService {
  static const String recordingsBoxName = 'recordings';
  static const String onboardingBoxName = 'onboarding';
  static late Box<Map> _recordingsBox;
  static late Box _onboardingBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _recordingsBox = await Hive.openBox<Map>(recordingsBoxName);
    _onboardingBox = await Hive.openBox(onboardingBoxName);
  }

  // Save a recording
  Future<void> saveRecording(Recording recording) async {
    await _recordingsBox.put(recording.id, recording.toJson());
  }

  // Get all recordings
  Future<List<Recording>> getAllRecordings() async {
    final recordings = _recordingsBox.values
        .map((json) => Recording.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    // Separate pinned and unpinned recordings
    final pinned = recordings.where((r) => r.isPinned).toList();
    final unpinned = recordings.where((r) => !r.isPinned).toList();

    // Sort pinned by date (newest first)
    pinned.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort unpinned by date (newest first)
    unpinned.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Return pinned first, then unpinned
    return [...pinned, ...unpinned];
  }

  // Get recording by ID
  Future<Recording?> getRecording(String id) async {
    final json = _recordingsBox.get(id);
    if (json == null) return null;
    return Recording.fromJson(Map<String, dynamic>.from(json));
  }

  // Update recording
  Future<void> updateRecording(Recording recording) async {
    await _recordingsBox.put(recording.id, recording.toJson());
  }

  // Delete recording
  Future<void> deleteRecording(String id) async {
    await _recordingsBox.delete(id);
  }

  // Search recordings by title or transcript
  Future<List<Recording>> searchRecordings(String query) async {
    final recordings = await getAllRecordings();
    final lowerQuery = query.toLowerCase();
    return recordings
        .where((rec) =>
    rec.displayTitle.toLowerCase().contains(lowerQuery) ||
        (rec.transcript?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  // Get recordings by tag
  Future<List<Recording>> getRecordingsByTag(String tag) async {
    final recordings = await getAllRecordings();
    return recordings.where((rec) => rec.tags.contains(tag)).toList();
  }

  // Get pinned recordings
  Future<List<Recording>> getPinnedRecordings() async {
    final recordings = await getAllRecordings();
    return recordings.where((rec) => rec.isPinned).toList();
  }

  // Get favorite recordings
  Future<List<Recording>> getFavoriteRecordings() async {
    final recordings = await getAllRecordings();
    return recordings.where((rec) => rec.isFavorite).toList();
  }

  // Clear all recordings
  Future<void> clearAll() async {
    await _recordingsBox.clear();
  }

  // Onboarding
  static bool getOnboardingComplete() {
    return _onboardingBox.get('onboarding_complete', defaultValue: false);
  }

  static Future<void> setOnboardingComplete(bool value) async {
    await _onboardingBox.put('onboarding_complete', value);
  }

  // Home screen tutorial (spotlight walkthrough)
  static bool getHomeTutorialSeen() {
    return _onboardingBox.get('home_tutorial_seen', defaultValue: false);
  }

  static Future<void> setHomeTutorialSeen(bool value) async {
    await _onboardingBox.put('home_tutorial_seen', value);
  }

  // In-card feature hints (first time a card is expanded)
  static bool getCardHintsSeen() {
    return _onboardingBox.get('card_hints_seen', defaultValue: false);
  }

  static Future<void> setCardHintsSeen(bool value) async {
    await _onboardingBox.put('card_hints_seen', value);
  }
}