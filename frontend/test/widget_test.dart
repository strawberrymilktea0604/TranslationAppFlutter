import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

import 'helpers/e2e_test_helper.dart';

void main() {
  testWidgets('app shell builds with test dependencies', (
    WidgetTester tester,
  ) async {
    await E2ETestHelper.setupTestEnvironment();
    addTearDown(E2ETestHelper.teardownTestEnvironment);

    await tester.pumpWidget(const MyApp());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
