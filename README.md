# Vocal Memo v1.2.0 - Refactored Edition

![Version](https://img.shields.io/badge/version-1.2.0-blue)
![Flutter](https://img.shields.io/badge/flutter-3.9.2-blue)
![License](https://img.shields.io/badge/license-Proprietary-red)

**Your Pocket Note Taker** – Record, transcribe, and organize voice memos with AI-powered features.

## 🆕 What's New in v1.2.0

### Major Features
✨ **AI-Powered Transcription** - Background transcription using Google's Gemini 2.0 Flash model  
🎨 **Audio Waveforms** - Visual waveform display for playback and trimming  
🎚️ **Interactive Trim UI** - Intuitive dual-handle trimming with visual feedback  
🔊 **Fixed Recording Beeps** - Beeps no longer captured in audio files  
🚀 **Performance Improvements** - Auto-dispose pattern prevents memory leaks

### Technical Improvements
- Replaced synchronous speech-to-text with async Gemini API
- Implemented proper resource disposal using Riverpod auto-dispose
- Added waveform visualization using `audio_waveforms` package
- Redesigned trim UI with interactive waveform selector
- Comprehensive error handling and logging

---

## 📋 Table of Contents
- [Quick Start](#quick-start)
- [Features](#features)
- [Architecture](#architecture)
- [Setup Guide](#setup-guide)
- [API Configuration](#api-configuration)
- [Development](#development)
- [Testing](#testing)
- [Documentation](#documentation)

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.9.2+
- Dart 3.0+
- Android Studio / VS Code
- Google Gemini API Key ([Get it here](https://aistudio.google.com/app/apikey))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/empyrealworks/vocal_memo.git
   cd vocal_memo
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env and add your GEMINI_API_KEY
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## ✨ Features

### Core Features
- 🎤 **Instant Recording** - One-tap voice recording with high quality audio
- 📝 **AI Transcription** - Accurate speech-to-text using Gemini 2.0 Flash
- 🎵 **Playback Controls** - Speed adjustment (1x, 1.5x, 2x), skip forward/backward
- 📂 **Organization** - Folders, tags, favorites, and pinning
- 🔍 **Search & Filter** - Find memos by keywords or metadata
- 🎙️ **Live Waveform** - Real-time visualization during playback
- ✂️ **Audio Trimming** - Remove unwanted sections with visual selector
- 💾 **Local Storage** - All data stored securely on-device

### New in v1.2.0
- **Background Transcription** - Transcribe after recording without blocking
- **Waveform Visualization** - See audio amplitude during playback
- **Interactive Trimming** - Dual-handle selector over waveform
- **Beep Management** - System beeps no longer in recordings
- **Memory Leak Prevention** - Automatic resource cleanup

---

## 🏗️ Architecture

### Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.9.2 |
| Language | Dart 3.0+ |
| State Management | Riverpod 3.0 |
| Local Storage | Hive |
| Audio Recording | record 6.1.2 |
| Audio Playback | audioplayers 6.5.1 |
| Waveform | audio_waveforms 1.1.0 |
| Audio Editing | FFmpeg Kit |
| Transcription | Gemini 2.0 Flash API |

### Project Structure
```
lib/
├── models/              # Data models
│   ├── recording.dart
│   ├── recording_settings.dart
│   ├── playback_state.dart
│   └── trim_segment.dart
├── providers/           # Riverpod state management
│   ├── recording_provider.dart
│   ├── transcription_provider.dart
│   ├── playback_provider.dart
│   └── settings_provider.dart
├── screens/            # UI screens
│   ├── home_screen.dart
│   ├── live_recording_screen.dart
│   ├── trim_screen.dart
│   └── settings_screen.dart
├── services/           # Business logic
│   ├── audio_service.dart
│   ├── gemini_transcription_service.dart
│   ├── playback_service.dart
│   ├── audio_editor_service.dart
│   └── storage_service.dart
├── widgets/            # Reusable components
│   ├── expandable_recording_card.dart
│   ├── playback_controls.dart
│   └── trim_widgets/
├── theme/              # App theming
│   └── app_theme.dart
├── utils/              # Utilities
│   └── time_formatter.dart
└── main.dart           # App entry point
```

### Design Patterns
- **Provider Pattern**: Riverpod for state management
- **Repository Pattern**: Storage service abstracts data layer
- **Service Pattern**: Services handle business logic
- **Auto-Dispose**: Automatic resource cleanup
- **Separation of Concerns**: Clear layer boundaries

---

## ⚙️ Setup Guide

### 1. Environment Configuration

Create `.env` file in project root:
```env
# Required: Get from https://aistudio.google.com/app/apikey
GEMINI_API_KEY=your_api_key_here

# Optional: Model selection (default: gemini-2.0-flash-exp)
GEMINI_MODEL=gemini-2.0-flash-exp
```

**Security Notes:**
- Never commit `.env` to version control
- Add `.env` to `.gitignore`
- Use different keys for dev/prod environments
- Rotate keys regularly

### 2. Android Configuration

Add permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Set minimum SDK in `android/app/build.gradle`:
```gradle
minSdkVersion 24
```

### 3. iOS Configuration

Add permissions to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Vocal Memo needs microphone access to record audio</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Vocal Memo needs access to save recordings</string>
```

Minimum iOS version: 12.0

---

## 🔑 API Configuration

### Getting Your Gemini API Key

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with Google account
3. Click "Get API Key"
4. Copy the key to your `.env` file

### API Usage & Limits

**Free Tier:**
- 15 requests per minute
- 1,500 requests per day
- 1 million requests per month

**Rate Limit Handling:**
The app will show an error if rate limit is exceeded. Wait 60 seconds and retry.

### Supported Models
- `gemini-2.0-flash-exp` (Recommended - Fast & accurate)
- `gemini-1.5-flash` (Stable, good for production)
- `gemini-1.5-pro` (Most accurate, slower)

Configure in `.env`:
```env
GEMINI_MODEL=gemini-2.0-flash-exp
```

---

## 🛠️ Development

### Running the App

**Debug Mode:**
```bash
flutter run
```

**Profile Mode (for performance testing):**
```bash
flutter run --profile
```

**Release Mode:**
```bash
flutter run --release
```

### Code Quality

**Run analyzer:**
```bash
flutter analyze
```

**Format code:**
```bash
dart format lib/
```

**Run tests:**
```bash
flutter test
```

### Building

**Android APK:**
```bash
flutter build apk --release
```

**iOS IPA:**
```bash
flutter build ios --release
```

### Debugging

**Enable verbose logging:**
```dart
// In main.dart
void main() {
  debugPrint('Debug mode enabled');
  runApp(MyApp());
}
```

**Check API key loaded:**
```dart
print('API Key: ${dotenv.env['GEMINI_API_KEY']?.substring(0, 10)}...');
```

**Monitor memory:**
```bash
flutter run --profile
# Then open DevTools → Memory tab
```

---

## 🧪 Testing

### Manual Testing Checklist

#### Recording
- [ ] Record 10 seconds of audio
- [ ] Verify no beeps in recording
- [ ] Test pause/resume
- [ ] Test with different formats (M4A, WAV, AAC)

#### Transcription
- [ ] Record clear speech
- [ ] Tap transcribe button
- [ ] Verify loading indicator
- [ ] Verify transcript accuracy
- [ ] Test with background noise
- [ ] Test with multiple speakers

#### Waveform
- [ ] Verify waveform loads
- [ ] Test seek by tapping waveform
- [ ] Verify playback indicator moves
- [ ] Test on long recordings (>5 minutes)

#### Trimming
- [ ] Open trim screen
- [ ] Adjust start/end handles
- [ ] Verify visual feedback
- [ ] Remove multiple sections
- [ ] Save trimmed audio
- [ ] Verify duration correct

### Automated Testing

**Unit Tests:**
```bash
flutter test test/unit/
```

**Widget Tests:**
```bash
flutter test test/widget/
```

**Integration Tests:**
```bash
flutter test integration_test/
```

---

## 📚 Documentation

### Key Documents
- **[REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)** - Complete technical guide
- **[MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)** - Step-by-step migration
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

### API Documentation

#### GeminiTranscriptionService
```dart
final service = GeminiTranscriptionService();

// Transcribe single file
String? transcript = await service.transcribeAudioFile(filePath);

// Transcribe multiple files
Map<String, String?> results = await service.transcribeBatch(filePaths);
```

#### AudioService
```dart
final service = AudioService();

// Start recording with settings
await service.startRecording(settings);

// Stop and get recording
Recording? recording = await service.stopRecording();

// Clean up
service.dispose();
```

### Code Examples

**Using transcription provider:**
```dart
// In widget
final transcript = ref.watch(transcribeRecordingProvider(recording));

transcript.when(
  data: (text) => Text(text ?? 'No transcript'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

**Using waveform:**
```dart
PlayerController controller = PlayerController();
await controller.preparePlayer(
  path: filePath,
  shouldExtractWaveform: true,
);

AudioFileWaveforms(
  playerController: controller,
  waveformType: WaveformType.fitWidth,
);
```

---

## 🐛 Troubleshooting

### Common Issues

**"GEMINI_API_KEY not found"**
- Verify `.env` file exists in project root
- Check API key is valid
- Restart IDE after creating .env

**"Transcription failed: 429"**
- Rate limit exceeded
- Wait 60 seconds and retry
- Consider upgrading to paid tier

**"Waveform not loading"**
- Check file path is correct
- Verify file format supported
- Try with shorter audio first

**"Memory leak detected"**
- Verify all controllers disposed
- Check provider auto-dispose
- Use DevTools memory profiler

### Debug Commands

```bash
# Check dependencies
flutter pub deps

# Clear cache
flutter clean && flutter pub get

# Rebuild app
flutter build apk --debug

# View logs
flutter logs
```

---

## 🤝 Contributing

This is proprietary software. For licensing inquiries, contact:

📧 **hello@empyrealworks.com**

---

## 📄 License

**Proprietary/Commercial License**

Vocal Memo is proprietary software developed and owned by Empyreal Digital Works.

- ✅ Personal use allowed
- ✅ Internal business use allowed
- ❌ Commercial redistribution prohibited
- ❌ Modification without permission prohibited

For licensing inquiries: **hello@empyrealworks.com**

---

## 🙏 Acknowledgments

### Technologies
- Flutter Team for the amazing framework
- Google for Gemini API
- FFmpeg for audio processing
- Riverpod for state management
- Hive for local storage

### Packages
- `audio_waveforms` by Usman Jamshed
- `audioplayers` by Blue Fire
- `record` by Llfbandit
- `google_generative_ai` by Google

---

## 📞 Support

### Get Help
- 📧 Email: **hello@empyrealworks.com**
- 📝 GitHub Issues: [Report a bug](https://github.com/empyrealworks/vocal_memo/issues)
- 📚 Documentation: Check [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)

### Feedback
We love hearing from you! Share your thoughts:
- Rate the app in store
- Email us feature requests
- Report bugs via GitHub Issues

---

## 🗺️ Roadmap

### v1.3.0 (Q2 2026)
- [ ] Cached waveform data
- [ ] Batch transcription UI
- [ ] Custom transcription languages
- [ ] Export transcripts (PDF/TXT)

### v1.4.0 (Q3 2026)
- [ ] Speaker diarization
- [ ] Timestamp markers
- [ ] Cloud backup (optional)
- [ ] Collaboration features

### v2.0.0 (Q4 2026)
- [ ] Offline transcription
- [ ] Real-time transcription option
- [ ] AI-powered audio enhancement
- [ ] Advanced search (semantic)

---

**Built with ❤️ by Empyreal Digital Works**  
**Version 1.2.0** | **March 2026**