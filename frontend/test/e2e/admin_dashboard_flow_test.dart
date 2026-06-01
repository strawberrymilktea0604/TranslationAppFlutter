import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/main_web.dart';
import '../helpers/e2e_test_helper.dart';
import '../helpers/e2e_seed_data.dart';

void main() {
  group('Admin Dashboard Flow E2E Tests', () {
    setUp(() async {
      await E2ETestHelper.setupTestEnvironment();
    });

    tearDown(() async {
      await E2ETestHelper.teardownTestEnvironment();
    });

    testWidgets(
      'A1: Admin can login with valid credentials',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
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
        await tester.pumpWidget(const AdminApp());
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
          'Chỉ có admin mới được phép đăng nhập vào dashboard.',
        );
      },
    );

    testWidgets(
      'A3: Admin can view dashboard with statistics',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);

        // Act
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await tester.pumpAndSettle();

        // Assert
        // Verify dashboard loaded with stats
        expect(find.byType(Card), findsWidgets);
        // Should show user count, translations, etc.
        expect(find.text('Dashboard'), findsWidgets);
      },
    );

    testWidgets(
      'A4: Admin can view user list',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
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
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

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
          'Đã khóa tài khoản User One',
        );
      },
    );

    testWidgets(
      'A6: Admin can unban a user',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

        // First, ban a user (tap ban icon → confirm dialog → confirm)
        var banButton = find.byIcon(Icons.block).first;
        await tester.tap(banButton);
        await tester.pumpAndSettle();

        // Confirm the ban dialog
        var confirmButton = find.text('Xác nhận');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }

        // Dismiss any existing SnackBar before proceeding
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
        await tester.pumpAndSettle();

        // Re-navigate to users page to force UI refresh
        // (the page doesn't auto-rebuild after ban via service.notifyListeners)
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();

        // Act
        // Now unban the user (icon changed to check_circle_outline after ban)
        final unbanButton = find.byIcon(Icons.check_circle_outline).first;
        await tester.tap(unbanButton);
        await tester.pumpAndSettle();

        // Confirm unban action
        confirmButton = find.text('Xác nhận');
        if (confirmButton.evaluate().isNotEmpty) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã mở khóa tài khoản User One',
        );
      },
    );

    testWidgets(
      'A7: Admin can view question banks',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
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
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Tap create button ("Tạo mới")
        final createButton = find.text('Tạo mới');
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        // Fill form - dialog uses TextFormField, not TextField
        final formFields = find.byType(TextFormField);
        await tester.enterText(formFields.at(0), 'Test Bank');
        await tester.enterText(formFields.at(1), 'Test Description');
        await tester.pumpAndSettle();

        // Submit (button text is "Tạo mới" for create mode)
        final submitButton = find.text('Tạo mới');
        // There are 2 "Tạo mới" - one in the header, one in the dialog. Tap the last one (dialog button).
        await tester.tap(submitButton.last);
        await tester.pumpAndSettle();

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã tạo ngân hàng câu hỏi "Test Bank"',
        );
      },
    );

    testWidgets(
      'A9: Admin can edit a question bank',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap options button for first bank
        final optionsButton = find.byTooltip('Tùy chọn').first;
        await tester.tap(optionsButton);
        await tester.pumpAndSettle();

        // Tap edit in popup menu
        final editMenuItem = find.text('Chỉnh sửa');
        await tester.tap(editMenuItem);
        await tester.pumpAndSettle();

        // Clear and enter new title - dialog uses TextFormField
        final titleField = find.byType(TextFormField).first;
        await tester.enterText(titleField, 'Updated Bank Title');
        await tester.pumpAndSettle();

        // Submit (button text is "Lưu thay đổi" for edit mode)
        final submitButton = find.text('Lưu thay đổi');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã cập nhật ngân hàng câu hỏi',
        );
      },
    );

    testWidgets(
      'A10: Admin can add question to quiz',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // The quiz editor auto-selects the first bank and loads its questions.
        // Wait for questions to load.
        await tester.pumpAndSettle();

        // Act
        // Tap add question button ("Thêm câu hỏi" in header)
        final addButton = find.text('Thêm câu hỏi').first;
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Fill question form - dialog uses TextFormField
        final formFields = find.byType(TextFormField);
        // First field is the content (question text)
        await tester.enterText(formFields.at(0), 'Test question?');

        // Choice fields: A, B, C, D (4 TextFormField for choices)
        await tester.enterText(formFields.at(1), 'Choice A');
        await tester.enterText(formFields.at(2), 'Choice B');
        await tester.enterText(formFields.at(3), 'Choice C');
        await tester.enterText(formFields.at(4), 'Choice D');
        await tester.pumpAndSettle();

        // Select correct answer (first Radio = "A")
        final radioButtons = find.byType(Radio<String>);
        if (radioButtons.evaluate().isNotEmpty) {
          await tester.tap(radioButtons.first);
          await tester.pumpAndSettle();
        }

        // Submit (button text is "Lưu")
        final submitButton = find.text('Lưu');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
        }

        // Assert - actual success message is 'Đã tạo câu hỏi mới'
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã tạo câu hỏi mới',
        );
      },
    );

    testWidgets(
      'A11: Admin can edit quiz question',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap edit button ("Sửa" OutlinedButton) for first question
        final editButton = find.text('Sửa').first;
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle();

          // Update question text - dialog uses TextFormField
          final contentField = find.byType(TextFormField).first;
          await tester.enterText(contentField, 'Updated question text?');
          await tester.pumpAndSettle();

          // Submit (button text is "Lưu")
          final submitButton = find.text('Lưu');
          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle();
          }
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã cập nhật câu hỏi',
        );
      },
    );

    testWidgets(
      'A12: Admin can delete quiz question',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuizEditor(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap delete button ("Xóa" OutlinedButton in question row)
        // Use the first OutlinedButton with text 'Xóa' (in the question row actions)
        final deleteButtonInRow = find.widgetWithText(OutlinedButton, 'Xóa').first;
        if (deleteButtonInRow.evaluate().isNotEmpty) {
          await tester.tap(deleteButtonInRow);
          await tester.pumpAndSettle();

          // Confirm deletion in AlertDialog (button text is "Xóa" with danger style)
          final confirmButton = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Xóa'),
          );
          if (confirmButton.evaluate().isNotEmpty) {
            await tester.tap(confirmButton);
            await tester.pumpAndSettle();
          }
        }

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã xóa câu hỏi',
        );
      },
    );

    testWidgets(
      'A13: Admin can toggle question bank active status',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await E2EAuthFlow.loginAsAdmin(tester);
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();

        // Act
        // Find and tap options button for first bank
        final optionsButton = find.byTooltip('Tùy chọn').first;
        await tester.tap(optionsButton);
        await tester.pumpAndSettle();

        // Tap toggle in popup menu
        final toggleMenuItem = find.text('Vô hiệu hóa');
        await tester.tap(toggleMenuItem);
        await tester.pumpAndSettle();

        // Assert
        E2ETestExpectations.expectSuccessMessage(
          tester,
          'Đã vô hiệu hóa "English Basics"',
        );
      },
    );

    testWidgets(
      'A14: Admin logout from dashboard',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
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
