// lib/services/gemini_transcription_service.dart
import 'dart:io';
import 'package:envied/envied.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:vocal_memo/env/env.dart';

/// Service for transcribing audio files using Google's Gemini API
///
/// This service handles asynchronous audio-to-text transcription by:
/// 1. Reading audio files from disk
/// 2. Uploading them to Gemini API
/// 3. Getting text transcription in response
class GeminiTranscriptionService {
  late final GenerativeModel _model;
  final String _apiKey;

  GeminiTranscriptionService({required String modelName})
      : _apiKey = Env.geminiApiKey{
    if (_apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY not found in environment variables. '
              'Please add your API key from https://aistudio.google.com/app/apikey'
      );
    }

    _model = GenerativeModel(
      model: modelName,
      apiKey: _apiKey,
    );
  }

  /// Transcribe an audio file to text
  ///
  /// [audioFilePath] - Full path to the audio file (.m4a, .wav, etc.)
  ///
  /// Returns the transcribed text or null if transcription fails
  ///
  /// Throws [FileSystemException] if file doesn't exist
  /// Throws [Exception] for API errors
  Future<String?> transcribeAudioFile(String audioFilePath, {String? modelName}) async {
    try {
      if (kDebugMode) {
        print('🎤 Starting transcription for: $audioFilePath');
      }

      // Verify file exists
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw FileSystemException(
          'Audio file not found',
          audioFilePath,
        );
      }

      // Read file as bytes
      final audioBytes = await file.readAsBytes();
      if (kDebugMode) {
        print('📁 File size: ${(audioBytes.length / 1024).toStringAsFixed(2)} KB');
      }

      // Determine MIME type based on file extension
      final extension = audioFilePath.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      if (kDebugMode) {
        print('📝 MIME type: $mimeType');
      }

      // Create the audio part for Gemini
      final audioPart = DataPart(mimeType, audioBytes);

      // Create the prompt
      final prompt = TextPart(
          'Please transcribe this audio recording accurately. '
              'Only return the transcribed text without any additional commentary, '
              'formatting, or explanations. If the audio is unclear or empty, '
              'return "Unable to transcribe audio".'
      );

      if (kDebugMode) {
        print('🤖 Using model: ${modelName ?? envied.name}');
      }

      // Send request to Gemini
      if (kDebugMode) {
        print('🚀 Sending request to Gemini API...');
      }
      final response = await _model.generateContent([
        Content.multi([prompt, audioPart])
      ]);

      // Extract and clean the text
      final text = response.text?.trim();

      if (text == null || text.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Gemini returned empty response');
        }
        return null;
      }

      // Check for error messages
      if (text.toLowerCase().contains('unable to transcribe')) {
        if (kDebugMode) {
          print('⚠️ Gemini unable to transcribe audio');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Transcription successful (${text.length} characters)');
      }
      return text;

    } on FileSystemException catch (e) {
      if (kDebugMode) {
        print('❌ File error: ${e.message}');
      }
      rethrow;
    } on GenerativeAIException catch (e) {
      if (kDebugMode) {
        print('❌ Gemini API error: ${e.message}');
      }
      throw Exception('Transcription failed: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during transcription: $e');
      }
      throw Exception('Transcription failed: $e');
    }
  }

  /// Transcribe multiple audio files in batch
  ///
  /// Returns a map of file paths to their transcriptions
  /// Files that fail to transcribe will have null values
  Future<Map<String, String?>> transcribeBatch(
      List<String> audioFilePaths,
      ) async {
    final results = <String, String?>{};

    for (final path in audioFilePaths) {
      try {
        results[path] = await transcribeAudioFile(path);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to transcribe $path: $e');
        }
        results[path] = null;
      }
    }

    return results;
  }

  /// Get MIME type based on file extension
  String _getMimeType(String extension) {
    switch (extension) {
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/mp4'; // Default to m4a
    }
  }

  /// Check if the service is properly configured
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Get the current model name
  // String get modelName => _model._model;
}