// lib/services/gemini_transcription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:vocal_memo/env/env.dart';

class GeminiTranscriptionService {
  late final GenerativeModel _model;
  final String _apiKey;

  // Maximum time we'll wait for a Gemini response before giving up.
  static const _apiTimeout = Duration(seconds: 90);

  GeminiTranscriptionService({required String modelName})
      : _apiKey = Env.geminiApiKey {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY not found in environment variables. '
            'Please add your API key from https://aistudio.google.com/app/apikey',
      );
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
    );
  }

  /// Transcribes [audioFilePath] to text using the Gemini API.
  ///
  /// Throws a descriptive [Exception] on:
  ///   - file not found
  ///   - API / network errors
  ///   - timeout (> [_apiTimeout])
  Future<String?> transcribeAudioFile(
      String audioFilePath, {
        String? modelName,
      }) async {
    if (kDebugMode) print('🎤 Starting transcription: $audioFilePath');

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw FileSystemException('Audio file not found', audioFilePath);
    }

    final audioBytes = await file.readAsBytes();
    if (kDebugMode) {
      print(
        '📁 File size: ${(audioBytes.length / 1024).toStringAsFixed(2)} KB',
      );
    }

    final extension = audioFilePath.split('.').last.toLowerCase();
    final mimeType = _getMimeType(extension);

    final audioPart  = DataPart(mimeType, audioBytes);
    final promptPart = TextPart(
      'Please transcribe this audio recording accurately. '
          'Only return the transcribed text without any additional commentary, '
          'formatting, or explanations. If the audio is unclear or empty, '
          'return "Unable to transcribe audio".',
    );

    try {
      if (kDebugMode) print('🚀 Sending request to Gemini (timeout: ${_apiTimeout.inSeconds}s)…');

      // ── Timeout guard ────────────────────────────────────────────────────────
      // The Gemini SDK does not impose its own timeout. Without this, a slow or
      // hung response will leave the transcription spinner running indefinitely.
      final response = await _model
          .generateContent([Content.multi([promptPart, audioPart])])
          .timeout(
        _apiTimeout,
        onTimeout: () => throw TimeoutException(
          'Transcription timed out after ${_apiTimeout.inSeconds} seconds. '
              'The file may be too large, or the service may be temporarily unavailable. '
              'Please try again.',
        ),
      );

      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        if (kDebugMode) print('⚠️ Gemini returned an empty response');
        return null;
      }
      if (text.toLowerCase().contains('unable to transcribe')) {
        if (kDebugMode) print('⚠️ Gemini could not transcribe the audio');
        return null;
      }

      if (kDebugMode) {
        print('✅ Transcription complete (${text.length} characters)');
      }
      return text;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏱ Transcription timed out: $e');
      throw Exception(e.message);
    } on FileSystemException {
      rethrow;
    } on GenerativeAIException catch (e) {
      if (kDebugMode) print('❌ Gemini API error: ${e.message}');
      throw Exception('Transcription failed: ${e.message}');
    } catch (e) {
      if (kDebugMode) print('❌ Unexpected transcription error: $e');
      throw Exception('Transcription failed: $e');
    }
  }

  /// Transcribes multiple files in sequence, returning a path → transcript map.
  Future<Map<String, String?>> transcribeBatch(
      List<String> audioFilePaths,
      ) async {
    final results = <String, String?>{};
    for (final path in audioFilePaths) {
      try {
        results[path] = await transcribeAudioFile(path);
      } catch (e) {
        if (kDebugMode) print('Failed to transcribe $path: $e');
        results[path] = null;
      }
    }
    return results;
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'm4a':  return 'audio/mp4';
      case 'wav':  return 'audio/wav';
      case 'mp3':  return 'audio/mpeg';
      case 'aac':  return 'audio/aac';
      case 'flac': return 'audio/flac';
      case 'ogg':  return 'audio/ogg';
      default:     return 'audio/mp4';
    }
  }

  bool get isConfigured => _apiKey.isNotEmpty;
}