# Vocal Memo

**Your Pocket Note Taker** – Record, transcribe, and organize your voice memos on the go with cloud backup.

## Overview

Vocal Memo is a Flutter-based voice recording app with AI transcription, cloud sync, and tiered features. Record ideas instantly, convert speech to text with Gemini AI, and sync your data across devices with Firebase.

## Features

### Core Features
- 🎤 **Instant Recording** – Tap to record voice memos anytime
- 🔒 **Background Recording** – Continues recording even when screen is locked
- 📝 **AI Transcription** – Convert speech to text using Gemini AI (tier-based models)
- 🎵 **Playback Controls** – Speed adjustment (1x, 1.5x, 2x), skip, rewind
- 📊 **Audio Waveforms** – Visual playback with tap-to-seek
- ✂️ **Audio Trimming** – Cut and edit recordings (requires registration)
- 📄 **Transcript Editor** – View, edit, copy, and share transcriptions

### Organization
- 📂 **Smart Organization** – Folders, tags, favorites, and pinning
- 🔍 **Search & Filter** – Find memos by keywords or metadata
- 🎨 **Customizable** – Light/Dark themes, configurable audio settings

### Cloud & Sync (Requires Account)
- ☁️ **Cloud Backup** – Never lose your recordings and transcripts
- 🔄 **Cross-Device Sync** – Access your data on any device
- 🔐 **Secure Authentication** – Email/password and Google Sign-In

## User Tiers

### 🆓 Unregistered (Local Only)
- Basic recording and playback
- Local storage only
- Limited features (no transcription or trimming)

### ✨ Registered (Free Account)
- AI transcription with Gemini 2.0 Flash
- Audio trimming and editing
- Cloud backup for recordings and settings
- Cross-device sync
- Transcript editor

### 💎 Subscribed (Coming Soon)
- Best AI model (Gemini 3.0 Flash when available)
- Priority processing
- Advanced features
- Unlimited cloud storage

## Tech Stack

- **Framework**: Flutter 3.9+
- **Language**: Dart 3.9+
- **State Management**: Riverpod
- **Local Storage**: Hive
- **Cloud Storage**: Firebase Firestore
- **Authentication**: Firebase Auth (Email + Google)
- **Audio Recording**: record package
- **Transcription**: Gemini AI API
- **Audio Processing**: FFmpeg

## Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable **Authentication** (Email/Password + Google)
4. Enable **Cloud Firestore**

### 2. Android Configuration
```bash
# Download google-services.json from Firebase Console
# Place it at: android/app/google-services.json
```

Add to `android/app/build.gradle`:
```gradle
plugins {
    id 'com.google.gms.google-services'
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
}
```

### 3. iOS Configuration
```bash
# Download GoogleService-Info.plist from Firebase Console
# Place it at: ios/Runner/GoogleService-Info.plist
```

### 4. Enable Google Sign-In
1. In Firebase Console → Authentication → Sign-in method
2. Enable Google provider
3. Add your SHA-1 fingerprint for Android:
```bash
cd android
./gradlew signingReport
```

## Environment Setup

Create `.env` file in project root:
```env
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.0-flash-exp
```

Get your Gemini API key from: https://aistudio.google.com/app/apikey

## Installation

1. **Clone the repository:**
```bash
git clone https://github.com/empyrealworks/vocal_memo.git
cd vocal_memo
```

2. **Set up Firebase:**
    - Complete Firebase setup steps above
    - Add `google-services.json` (Android)
    - Add `GoogleService-Info.plist` (iOS)

3. **Create `.env` file:**
```bash
echo "GEMINI_API_KEY=your_key_here" > .env
echo "GEMINI_MODEL=gemini-2.0-flash-exp" >> .env
```

4. **Install dependencies:**
```bash
flutter pub get
```

5. **Run the app:**
```bash
flutter run
```

## Firestore Data Structure

```
users/
  {userId}/
    recordings/
      {recordingId}/
        - id, fileName, filePath, createdAt
        - duration, transcript, isFavorite
        - isPinned, tags
    settings/
      preferences/
        - autoGainControl, noiseSuppression
        - themeMode, showWaveform
        - lastUpdated
```

## Usage

### Registration (Optional but Recommended)
- **Sign Up**: Tap transcribe or trim → Create account
- **Benefits**: Cloud backup, better AI, cross-device sync
- **Free forever**: No credit card required

### Recording
- Tap **mic button** to start
- Recording continues when screen locks
- Tap **stop** to finish

### Transcription (Requires Registration)
- Expand recording → Tap **transcribe icon**
- Automatic cloud sync after transcription

### Trimming (Requires Registration)
- Expand recording → Tap **trim icon**
- Select regions to remove → Save

## Version History

### v1.3.0 (Current)
- ✨ Firebase authentication
- ☁️ Cloud sync
- 🎯 Tier-based AI models
- 🔒 Feature gating

### v1.2.1
- 🔒 Background recording
- 📝 Transcript editor
- 🎨 Waveform toggle

### v1.2.0
- 🤖 Gemini AI transcription
- 🎵 Audio waveforms
- ✂️ Audio trimming

## Troubleshooting

**Firebase not initialized:**
- Verify `google-services.json` / `GoogleService-Info.plist` locations
- Ensure `Firebase.initializeApp()` in `main()`

**Google Sign-In fails:**
- Add SHA-1 to Firebase Console
- Enable Google provider
- Update `google-services.json`

**Transcription blocked:**
- Sign up for free account
- Check internet connection
- Verify Gemini API key in `.env`

## License

Proprietary software by Empyreal Digital Works.  
Personal use allowed. Commercial redistribution requires written agreement.

📧 **hello@empyrealworks.com**

---

Built with ❤️ using Flutter | Powered by Gemini AI | Secured by Firebase

## v1.3.1 Updates

### Firebase Storage
- Audio files uploaded to Firebase Storage for cloud backup
- Automatic sync of recordings when authenticated
- Download capability for cross-device access

### Feature Gating & Limits
- **1-minute limit** for unregistered users on transcription
- **10 transcriptions per day** for registered users
- Rate limit badge on transcribe button showing remaining count
- Reusable feature gate dialog for upgrades

### Search & Filters
- Advanced search filters: duration, date range, transcript search
- Filter by recording length (30s, 1m, 5m, 10m, 30m, 1h)
- Date range picker (from/to)
- Transcript search (registered users only)
- Active filter badge on search bar

### Bug Fixes
- Fixed Riverpod dispose error in trim screen
- Fixed auth state not refreshing after sign in/out
- Improved auth provider reactivity with force re-evaluation

### Dependencies Added
```yaml
firebase_storage: ^12.3.4
```

### Firestore Security Rules
```javascript
// Add to Firestore Rules
match /users/{userId}/usage/{document} {
  allow read, write: if request.auth.uid == userId;
}
```

### Firebase Storage Rules
```javascript
// Add to Storage Rules
match /users/{userId}/{allPaths=**} {
  allow read, write: if request.auth.uid == userId;
}
```