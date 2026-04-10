// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Ứng dụng Dịch thuật';

  @override
  String get login => 'Đăng nhập';

  @override
  String get register => 'Đăng ký';

  @override
  String get translate => 'Dịch';

  @override
  String get history => 'Lịch sử';

  @override
  String get vocabulary => 'Từ vựng';

  @override
  String get settings => 'Cài đặt';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mật khẩu';

  @override
  String get sourceText => 'Nhập văn bản cần dịch...';

  @override
  String get translatedText => 'Bản dịch sẽ hiển thị ở đây...';

  @override
  String get offlineMode => 'Chế độ ngoại tuyến';

  @override
  String get syncData => 'Đồng bộ dữ liệu';
}
