import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'chat_list_screen.dart';
import 'intro_screen_stub.dart';
import 'settings_screen.dart';

/// Pairs a visible tab screen with its bottom-nav destination.
/// To add or reorder tabs for a user type, edit [_tabsFor] only —
/// MainNavigationScreen never needs to change.
class _Tab {
  const _Tab({required this.screen, required this.destination});
  final Widget screen;
  final NavigationDestination destination;
}

/// Returns the tab list for the given user layout.
/// Both guest (intro) and admin (dashboard) currently share the same layout.
List<_Tab> _tabsFor(String uiLayout) {
  // Shared layout: Assistant → Insights.
  // Settings is appended separately and reached via the AppBar gear icon.
  return const [
    _Tab(
      screen: ChatListScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: 'Assistant',
      ),
    ),
    _Tab(
      screen: InsightsPreviewScreen(),
      destination: NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: 'Insights',
      ),
    ),
  ];
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  Future<void> _handleDestinationSelected(
    int index,
    AuthProvider authProvider,
    List<_Tab> tabs,
  ) async {
    const chatIndex = 0;

    if (index == chatIndex && !authProvider.aiEnabled) {
      final enabled = await _showEnableAiPrompt();
      if (!enabled) return;
    }

    if (mounted) setState(() => _currentIndex = index);
  }

  Future<void> _handleSelectSettings(
    AuthProvider authProvider,
    List<_Tab> tabs,
  ) async {
    // Settings is always the screen after the visible tabs.
    await _handleDestinationSelected(tabs.length, authProvider, tabs);
  }

  PreferredSizeWidget _buildTopBar(AuthProvider authProvider, List<_Tab> tabs) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.black;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      titleSpacing: 0,
      centerTitle: false,
      actionsPadding: EdgeInsets.zero,
      title: Container(
        width: 60,
        height: 60,
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, left: 12),
          child: SvgPicture.asset(
            'assets/images/companion-logo.svg',
            width: 36,
            height: 36,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: InkWell(
              onTap: () => _handleSelectSettings(authProvider, tabs),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.settings_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _showEnableAiPrompt() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn on AI Chat?'),
        content: const Text(
          'AI Chat is currently disabled in your account settings. '
          'Would you like to turn it on now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn on AI'),
          ),
        ],
      ),
    );

    if (shouldEnable != true) return false;

    final enabled = await authProvider.enableAi();

    if (!enabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Unable to enable AI right now.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return enabled;
  }

  int _resolveBottomIndex(int tabCount) {
    if (_currentIndex < 0 || _currentIndex >= tabCount) return 0;
    return _currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final tabs = _tabsFor(authProvider.user?.uiLayout ?? 'intro');
        final screens = [...tabs.map((t) => t.screen), const SettingsScreen()];
        final destinations = tabs.map((t) => t.destination).toList();
        final bg = Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.black;

        if (_currentIndex >= screens.length) _currentIndex = 0;

        return Scaffold(
          backgroundColor: bg,
          appBar: _buildTopBar(authProvider, tabs),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: bg,
            selectedIndex: _resolveBottomIndex(tabs.length),
            onDestinationSelected: (index) =>
                _handleDestinationSelected(index, authProvider, tabs),
            destinations: destinations,
          ),
        );
      },
    );
  }
}
