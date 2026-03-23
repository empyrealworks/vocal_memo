import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_memo/widgets/custom_dialog.dart';

void main() {
  testWidgets('CustomDialog displays correct information', (WidgetTester tester) async {
    bool confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  CustomDialog.show(
                    context,
                    icon: Icons.delete,
                    title: 'Delete Memo',
                    message: 'Are you sure?',
                    confirmText: 'Yes',
                    onConfirm: () => confirmed = true,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            );
          },
        ),
      ),
    );

    // Show the dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Delete Memo'), findsOneWidget);
    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    // Confirm action
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byType(CustomDialog), findsNothing);
  });

  testWidgets('CustomDialog cancel button dismisses dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  CustomDialog.show(
                    context,
                    icon: Icons.info,
                    title: 'Title',
                    message: 'Message',
                    confirmText: 'OK',
                    onConfirm: () {},
                  );
                },
                child: const Text('Show'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomDialog), findsNothing);
  });
}
