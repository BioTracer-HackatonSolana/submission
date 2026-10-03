import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/app_state.dart';
import '../widgets/app_chrome.dart';
import 'dashboard_screen.dart';
import 'action_screen.dart';
import 'history_screen.dart';
import 'account_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeRole = ref.watch(activeRoleProvider);
    final controller = ref.watch(traceFlowProvider);

    final screens = [
      const DashboardScreen(),
      const ActionScreen(),
      const HistoryScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      appBar: AppTopBar(
        activeRole: activeRole,
        onRoleChanged: (OrganizationKind newValue) {
          ref.read(activeRoleProvider.notifier).state = newValue;
          setState(() {
            _currentIndex = 0;
          });
        },
        onReset: controller.isBusy ? null : () => controller.reset(),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: AppBottomNav(
        index: _currentIndex,
        role: activeRole,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
