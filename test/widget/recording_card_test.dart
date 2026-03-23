import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/models/recording.dart';
import 'package:vocal_memo/widgets/expandable_recording_card.dart';
import 'package:vocal_memo/theme/app_theme.dart';

void main() {
  final testRecording = Recording(
    id: '1',
    fileName: 'test.m4a',
    title: 'Test Memo',
    filePath: '/path/test.m4a',
    createdAt: DateTime.now(),
    duration: const Duration(seconds: 30),
  );

  testWidgets('ExpandableRecordingCard shows title and duration', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExpandableRecordingCard(recording: testRecording),
          ),
        ),
      ),
    );

    expect(find.text('Test Memo'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('ExpandableRecordingCard expands on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [ExpandableRecordingCard(recording: testRecording)],
            ),
          ),
        ),
      ),
    );

    // Initial state: not expanded (Transcript preview not visible yet)
    expect(find.text('Transcript preview coming soon'), findsNothing);

    // Tap to expand
    await tester.tap(find.text('Test Memo'));
    await tester.pumpAndSettle();

    // Now should be expanded
    // Note: TranscriptPreviewBox might show different text depending on recording state
    // but we expect more UI to be visible.
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });
}
