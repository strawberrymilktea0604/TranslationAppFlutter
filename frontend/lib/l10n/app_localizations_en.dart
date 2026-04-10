// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Translation App';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get translate => 'Translate';

  @override
  String get history => 'History';

  @override
  String get vocabulary => 'Vocabulary';

  @override
  String get settings => 'Settings';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get sourceText => 'Enter text to translate...';

  @override
  String get translatedText => 'Translation will appear here...';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get syncData => 'Sync Data';
}
