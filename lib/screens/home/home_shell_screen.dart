import 'package:flutter/material.dart';
import 'home_dashboard_screen.dart';
import '../dashboard_screen.dart';
import '../order_history_screen.dart';
import '../attendance_screen.dart';
import '../profile_screen.dart';
import '../../services/attendance_service.dart';
import '../../services/location_tracking_service.dart';

/// Top-level shell for the Salesman experience: a bottom navigation bar
/// with 5 tabs — Home, Visits, Orders, Attendance, Profile — matching the
/// mockup. Each tab keeps its own state via IndexedStack (switching tabs
/// doesn't reset scroll position or in-flight loads).
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // If the app was closed and reopened mid-shift (checked in, not yet
    // checked out today), resume location pings without making the
    // salesperson check in again.
    AttendanceService().getTodayAttendance().then((today) {
      final onShift = today != null && today.checkOutTime == null;
      LocationTrackingService.instance.resumeIfAlreadyOnShift(isOnShift: onShift);
    }).catchError((_) {});
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboardScreen(onNavigateToTab: _goToTab),
      const DashboardScreen(),
      const OrderHistoryScreen(),
      const AttendanceScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Visits'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.access_time_outlined), selectedIcon: Icon(Icons.access_time), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
