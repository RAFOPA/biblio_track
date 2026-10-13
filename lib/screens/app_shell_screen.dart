import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/swipe_tab_body.dart';
import 'home_screen.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';
import 'reservations_screen.dart';
import 'search_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  final _pageController = PageController();
  final _currentIndex = ValueNotifier<int>(0);

  static const _pages = <Widget>[
    _KeepAlivePage(child: HomeScreen(embedded: true)),
    _KeepAlivePage(child: SearchScreen(embedded: true)),
    _KeepAlivePage(child: ReservationsScreen(embedded: true)),
    _KeepAlivePage(child: LoansScreen(embedded: true)),
    _KeepAlivePage(child: ProfileScreen(embedded: true)),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _pages.length || index == _currentIndex.value) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (_currentIndex.value == index) return;
    _currentIndex.value = index;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AppTabScope(
    onNavigate: _selectTab,
    currentIndex: _currentIndex,
    child: Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        onPageChanged: _handlePageChanged,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex.value,
        onTap: _selectTab,
      ),
    ),
  );
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
