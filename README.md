# Vocal Memo

**Your Pocket Note Taker** – Record, transcribe, and organize your voice memos on the go.

## Overview

Vocal Memo is a Flutter-based voice recording app that lets users capture ideas instantly, convert speech to text automatically, and organize recordings with tags, folders, and favorites. All data is stored locally on-device for privacy.

## Features

- 🎤 **Instant Recording** – Tap to record voice memos anytime
- 📝 **Auto-Transcription** – Convert speech to text on-device
- 🎵 **Playback Controls** – Speed adjustment (1x, 1.5x, 2x), skip, rewind
- 📂 **Organization** – Folders, tags, favorites, and pinning
- 🔍 **Search & Filter** – Find memos by keywords or metadata
- 🎙️ **Live Mic** – Real-time waveform visualization while recording
- 💾 **On-Device Storage** – All recordings and transcripts saved locally

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider / Riverpod (TBD)
- **Local Storage**: Hive / SQLite
- **Audio Recording**: flutter_sound or record package
- **Transcription**: speech_to_text (on-device via native APIs)

## Project Structure

lib/
├── screens/
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── recording_details_screen.dart
│   └── live_recording_screen.dart
├── models/
│   ├── recording.dart
│   └── tag.dart
├── services/
│   ├── audio_service.dart
│   ├── transcription_service.dart
│   └── storage_service.dart
├── widgets/
│   ├── recording_card.dart
│   ├── waveform_painter.dart
│   └── playback_controls.dart
├── main.dart
└── theme/
└── app_theme.dart

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Dart 2.19+
- iOS 12+ or Android 7+

### Installation

1. Clone the repository:
```bash
   git clone https://github.com/empyrealworks/vocal_memo.git
   cd vocal-memo
```

2. Install dependencies:
```bash
   flutter pub get
```

3. Run the app:
```bash
   flutter run
```

## Configuration

### Android

Add microphone permission to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS

Add microphone permission to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Vocal Memo needs microphone access to record audio</string>
```

## Color Palette

- **Teal**: #6CD6CE
- **Orange**: #F86E01

## MVP Features (v1.0)

- ✅ Record audio
- ✅ On-device transcription
- ✅ Playback with speed control
- ✅ Basic organization (tags, folders, favorites, pinning)
- ✅ Search and filtering
- ✅ Live recording visualization

## Updates
### v1.1

- ✅ Dark Theme
- ✅ Audio Trimming
- ✅ Noise Suppression
- ✅ Bitrate (Kbps) and Sample Rate (Hz) Selection
- ✅ Multiple Audio Format (M4A, WAV, AAC, FLAC)
- ✅ File Sharing

## Future Enhancements

- Cloud sync (optional)
- Export to multiple formats (MP3, WAV, PDF)
- Collaboration/sharing features
- Voice commands
- Custom shortcuts
- Analytics dashboard

## Contributing

Contributions welcome! Please fork the repo and submit a pull request.

## License Summary

**Vocal Memo** is proprietary software developed and owned by **Empyreal Digital Works**.  
The source code and all accompanying assets are **not open-source** and may not be copied, modified, or redistributed without explicit permission.

Personal and internal business use is allowed under the [Proprietary/Commercial License](./LICENSE.md).  
Commercial redistribution or inclusion in other products requires a separate written agreement.

📧 For licensing or redistribution inquiries: **hello@empyrealworks.com**


## Support

For issues or feature requests, open an issue on GitHub or contact support.

---

Built with ❤️ using Flutter