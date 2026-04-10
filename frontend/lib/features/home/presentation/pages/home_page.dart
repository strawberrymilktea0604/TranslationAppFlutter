import 'package:flutter/material.dart';
import 'package:frontend/features/translation/presentation/pages/translation_page.dart';
import 'package:frontend/features/vocabulary/presentation/pages/vocabulary_page.dart';
import 'package:frontend/features/history/presentation/pages/history_page.dart';
import 'package:frontend/features/home/presentation/pages/settings_page.dart';

/// Home page containing the bottom navigation bar.
///
/// Manages four main tabs:
/// 1. Translation — Main translation feature (UC01, UC02, UC03)
/// 2. Vocabulary — Saved vocabulary list (UC07)
/// 3. History — Translation history (UC08)
/// 4. Settings — User profile & app settings (UC04)
///
/// Each tab displays its corresponding placeholder page.
/// WriteCubits for each feature should be scoped per-tab
/// when actual implementations are wired.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  /// Pages for each tab. Each is a placeholder widget until
  /// the feature is fully implemented.
  static const List<Widget> _pages = <Widget>[
    TranslationPlaceholderPage(),
    VocabularyPlaceholderPage(),
    HistoryPlaceholderPage(),
    SettingsPlaceholderPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: 'Dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Từ vựng',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
