// lib/models/recording.dart
import 'package:intl/intl.dart';
import 'package:vocal_memo/services/encryption_service.dart';

class Recording {
  final String id;
  final String fileName;
  String? title;
  final String filePath;
  final DateTime createdAt;
  final Duration duration;
  bool isFavorite;
  bool isPinned;
  final List<String> tags;
  final String? folderId;
  String? transcript;
  bool isTranscribing;
  List<double>? waveformData = [];
  
  /// Number of audio channels (1 for mono, 2 for stereo).
  final int numChannels;

  /// Firebase Storage download URL for the encrypted audio backup.
  /// Null until the user manually triggers a backup.
  final String? backupUrl;

  Recording({
    required this.id,
    required this.fileName,
    this.title,
    required this.filePath,
    required this.createdAt,
    required this.duration,
    this.isFavorite = false,
    this.isPinned = false,
    this.tags = const [],
    this.folderId,
    this.transcript,
    this.isTranscribing = false,
    this.waveformData,
    this.numChannels = 1,
    this.backupUrl,
  });

  /// Whether this recording has been backed up to Firebase Storage.
  bool get isBackedUp => backupUrl != null && backupUrl!.isNotEmpty;

  bool get isStereo => numChannels == 2;

  String get displayTitle =>
      title ?? 'Memo ${DateFormat('MMM d, h:mm a').format(createdAt)}';

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAt);

  String get formattedTime => DateFormat('h:mm a').format(createdAt);

  String get displayTranscript {
    if (transcript == null || transcript!.isEmpty) return '';
    return EncryptionService.decrypt(transcript!);
  }

  // ─── Serialisation ────────────────────────────────────────────

  /// Full serialisation used for local Hive storage.
  /// Includes [waveformData] so waveforms survive app restarts without
  /// re-processing the audio file.
  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'title': title,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'tags': tags,
    'folderId': folderId,
    'transcript': transcript,
    'isTranscribing': isTranscribing,
    'waveformData': waveformData,
    'numChannels': numChannels,
    'backupUrl': backupUrl,
  };

  /// Cloud serialisation used for Firestore documents.
  Map<String, dynamic> toCloudJson() => {
    'id': id,
    'fileName': fileName,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'tags': tags,
    'folderId': folderId,
    'transcript': transcript,
    'isTranscribing': isTranscribing,
    'numChannels': numChannels,
    'backupUrl': backupUrl,
  };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    title: json['title'] as String?,
    filePath: json['filePath'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    duration: Duration(milliseconds: json['durationMs'] as int),
    isFavorite: json['isFavorite'] as bool? ?? false,
    isPinned: json['isPinned'] as bool? ?? false,
    tags: List<String>.from(json['tags'] as List? ?? []),
    folderId: json['folderId'] as String?,
    transcript: json['transcript'] as String?,
    isTranscribing: json['isTranscribing'] as bool? ?? false,
    waveformData:
    List<double>.from(json['waveformData'] as List? ?? []),
    numChannels: json['numChannels'] as int? ?? 1,
    backupUrl: json['backupUrl'] as String?,
  );

  Recording copyWith({
    String? id,
    String? fileName,
    String? title,
    String? filePath,
    DateTime? createdAt,
    Duration? duration,
    bool? isFavorite,
    bool? isPinned,
    List<String>? tags,
    String? folderId,
    String? transcript,
    bool? isTranscribing,
    List<double>? waveformData,
    int? numChannels,
    String? backupUrl,
    bool clearBackupUrl = false,
  }) =>
      Recording(
        id: id ?? this.id,
        fileName: fileName ?? this.fileName,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        createdAt: createdAt ?? this.createdAt,
        duration: duration ?? this.duration,
        isFavorite: isFavorite ?? this.isFavorite,
        isPinned: isPinned ?? this.isPinned,
        tags: tags ?? this.tags,
        folderId: folderId ?? this.folderId,
        transcript: transcript ?? this.transcript,
        isTranscribing: isTranscribing ?? this.isTranscribing,
        waveformData: waveformData ?? this.waveformData,
        numChannels: numChannels ?? this.numChannels,
        backupUrl: clearBackupUrl ? null : (backupUrl ?? this.backupUrl),
      );
}