import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/widgets/access_locked_dialog.dart';

void main() {
  testWidgets('AccessLockedDialog renders locked message and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccessLockedDialog(featureName: 'Practice Questions'),
        ),
      ),
    );

    expect(find.text('Access Locked'), findsOneWidget);
    expect(
      find.text('Please complete your payment and submit your payment receipt for verification to unlock Practice Questions.'),
      findsOneWidget,
    );
    expect(find.text('Submit Payment Receipt'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });
}
