import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import '../helpers/e2e_test_helper.dart';
import '../helpers/e2e_seed_data.dart';

void main() {
  group('Admin Dashboard Flow E2E Tests', () {
    setUpAll(() async {
      await E2ETestHelper.setupTestEnvironment();
    });

    tearDownAll(() async {
      await E2ETestHelper.teardownTestEnvironment();
    });

    testWidgets(
      'A1: Admin can login with valid credentials',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act
        await E2EAuthFlow.loginAsAdmin(tester);

        // Assert
        expect(find.byType(Scaffold), findsWidgets);
        E2ETestExpectations.expectNoError(tester);
      },
    );

    testWidgets(
      'A2: Admin login fails with non-admin account',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act
        // Try to access admin screen with regular user
        await E2EAuthFlow.loginAsUser(tester);

        // Try to navigate to admin
        await E2EScreenNavigation.navigateToAdminDashboard(tester);

        // Assert
        // Should not have access
        E2ETestExpectations.expectErrorMessage(
          tester,
          'Forbidden',
        );
      },
    );

    testWidgets(
      'A3: Admin can view dashboard with statistics',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);

        // Act
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await tester.pumpAndSettle();

        // Assert
        // Verify dashboard loaded with stats
        expect(find.byType(Card), findsWidgets);
        // Should show user count, translations, etc.
        expect(find.text('Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'A4: Admin can view user list',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);

        // Act
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(ListView), findsWidgets);
        // Check users are loaded from seed data
        for (final user in E2ETestSeedData.seedAdminUsers) {
          expect(
            find.text(user['email'] as String),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'A5: Admin can ban a user',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

        final userEmail = E2ETestSeedData.seedAdminUsers[0]['email'];

        // Act
        // Find and tap ban button for first user
        final banButton = find.byIcon(Icons.block).first;
        await tester.tap(banButton);
        await tester.pumpAndSettle();

        // Confirm ban action if dialog exists
        final confirmButton = find.text('Xác nhận');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã khóa',
        );
      },
    );

    testWidgets(
      'A6: Admin can unban a user',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

        // First, ban a user
        var banButton = find.byIcon(Icons.block).first;
        await tester.tap(banButton);
        await tester.pumpAndSettle();

        // Act
        // Now unban the user
        final unbanButton = find.byIcon(Icons.check_circle).first;
        await tester.tap(unbanButton);
        await tester.pumpAndSettle();

        // Confirm action
        final confirmButton = find.text('Xác nhận');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã mở khóa',
        );
      },
    );

    testWidgets(
      'A7: Admin can view question banks',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);

        // Act
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(ListView), findsWidgets);
        // Check banks are loaded
        for (final bank in E2ETestSeedData.seedQuestionBanks) {
          expect(
            find.text(bank['title'] as String),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'A8: Admin can create a new question bank',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Tap create button
        final createButton = find.byIcon(Icons.add).first;
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // Fill form
        await tester.enterText(
          find.byType(TextField).at(0),
          'Test Bank',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'Test Description',
        );
        await tester.pumpAndSettle();

        // Submit
        final submitButton = find.text('Tạo');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã tạo',
        );
      },
    );

    testWidgets(
      'A9: Admin can edit a question bank',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap edit button
        final editButton = find.byIcon(Icons.edit).first;
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Clear and enter new title
        final titleField = find.byType(TextField).first;
        await tester.tap(titleField);
        await tester.pumpAndSettle();
        await tester.enterText(titleField, 'Updated Bank Title');
        await tester.pumpAndSettle();

        // Submit
        final submitButton = find.text('Cập nhật');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã cập nhật',
        );
      },
    );

    testWidgets(
      'A10: Admin can add question to quiz',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // Select a bank
        final bankDropdown = find.byType(DropdownButton);
        if (bankDropdown.evaluate().isNotEmpty) {
          await tester.tap(bankDropdown.first);
          await tester.pumpAndSettle();

          final bankOption = find.text('English Basics');
          if (bankOption.evaluate().isNotEmpty) {
            await tester.tap(bankOption);
            await tester.pumpAndSettle();
          }
        }

        // Act
        // Tap add question button
        final addButton = find.byIcon(Icons.add).first;
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Fill question form
        await tester.enterText(
          find.byType(TextField).at(0),
          'Test question?',
        );

        // Add choices
        await tester.enterText(
          find.byType(TextField).at(1),
          'Choice A',
        );
        await tester.enterText(
          find.byType(TextField).at(2),
          'Choice B',
        );

        // Select correct answer
        final radioButtons = find.byType(Radio);
        if (radioButtons.evaluate().isNotEmpty) {
          await tester.tap(radioButtons.first);
          await tester.pumpAndSettle();
        }

        // Submit
        final submitButton = find.text('Tạo');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã tạo',
        );
      },
    );

    testWidgets(
      'A11: Admin can edit quiz question',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap edit button for first question
        final editButton = find.byIcon(Icons.edit).first;
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle();

          // Update question text
          final textField = find.byType(TextField).first;
          await tester.tap(textField);
          await tester.pumpAndSettle();
          await tester.enterText(
            textField,
            'Updated question text?',
          );

          // Submit
          final submitButton = find.text('Cập nhật');
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle();
          }
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã cập nhật',
        );
      },
    );

    testWidgets(
      'A12: Admin can delete quiz question',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap delete button
        final deleteButton = find.byIcon(Icons.delete).first;
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          // Confirm deletion
          final confirmButton = find.text('Xóa');
          if (confirmButton.evaluate().isNotEmpty) {
            await tester.tap(confirmButton);
            await tester.pumpAndSettle();
          }
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã xóa',
        );
      },
    );

    testWidgets(
      'A13: Admin can toggle question bank active status',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap toggle button
        final toggleButton = find.byIcon(Icons.toggle_on).first;
        if (toggleButton.evaluate().isNotEmpty) {
          await tester.tap(toggleButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã cập nhật',
        );
      },
    );

    testWidgets(
      'A14: Admin logout from dashboard',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);

        // Act
        await E2EAuthFlow.logout(tester);

        // Assert
        // Should return to login
        E2ETestExpectations.expectNoError(tester);
      },
    );
  });
}
