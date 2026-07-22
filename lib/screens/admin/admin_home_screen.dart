import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/coming_soon.dart';
import '../notifications_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_salesmen_screen.dart';
import 'admin_live_tracking_screen.dart';

/// The Admin Home dashboard — "Sales Overview". Every stat here reads
/// real data from Supabase (see AdminDashboardService). The 5 quick
/// actions route to real screens where they exist (Salesmen, Live
/// Track, Orders) and to a "Coming Soon" placeholder otherwise
/// (Dealers, Reports).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _dashboardService = AdminDashboardService();
  final _authService = AuthService();

  late Future<AdminOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = _dashboardService.loadOverview();
  }

  void _refresh() => setState(() {
        _future = _dashboardService.loadOverview();
      });

  String _formatLakhs(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  Future<void> _openSalesmen() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSalesmenScreen()));
    _refresh();
  }

  Future<void> _openOrders() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    _refresh();
  }

  Future<void> _openLiveTracking() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLiveTrackingScreen()));
    _refresh();
  }

  void _openDealers() {
    showComingSoon(
      context,
      feature: 'Dealer Management',
      detail: 'A company-wide view of every dealer/outlet is coming soon.',
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen(isAdmin: true)));
    _refresh();
  }

  void _openReports() {
    showComingSoon(
      context,
      feature: 'Reports',
      detail: 'Downloadable sales, attendance, and performance reports are coming soon.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<AdminOverview>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text('Error: ${snapshot.error}')),
                  ],
                );
              }
              final data = snapshot.data!;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(context),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatsGrid(data),
                            const SizedBox(height: 16),
                            _buildQuickActions(),
                            const SizedBox(height: 16),
                            _buildWeeklyChart(data),
                            const SizedBox(height: 16),
                            _buildAttendanceDonut(data),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final today = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D6BFF), Color(0xFF1530A6)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Panel',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sales Overview',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, d MMMM y').format(today),
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
            child: IconButton(
              onPressed: () => showComingSoon(context, feature: 'Settings'),
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
            ),
          ),
          IconButton(
            onPressed: () => _authService.signOut(),
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AdminOverview data) {
    final stats = [
      _StatCardData(
        icon: Icons.groups_outlined,
        iconColor: const Color(0xFF3D6BFF),
        iconBg: const Color(0xFFE7EDFF),
        value: '${data.totalSalesmen}',
        label: 'Total Salesmen',
        onTap: _openSalesmen,
      ),
      _StatCardData(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFE3F7EA),
        value: '${data.presentToday}',
        label: 'Present Today',
        onTap: _openSalesmen,
      ),
      _StatCardData(
        icon: Icons.shopping_bag_outlined,
        iconColor: const Color(0xFF7C3AED),
        iconBg: const Color(0xFFF1E7FF),
        value: '${data.totalOrders}',
        label: 'Total Orders',
        onTap: _openOrders,
      ),
      _StatCardData(
        icon: Icons.error_outline,
        iconColor: const Color(0xFFEA8C00),
        iconBg: const Color(0xFFFFF1DC),
        value: '${data.pendingOrders}',
        label: 'Pending Orders',
        onTap: _openOrders,
      ),
      _StatCardData(
        icon: Icons.location_on_outlined,
        iconColor: const Color(0xFF3D6BFF),
        iconBg: const Color(0xFFE7EDFF),
        value: '${data.todaysVisits}',
        label: "Today's Visits",
        onTap: _openOrders,
      ),
      _StatCardData(
        icon: Icons.show_chart,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFE3F7EA),
        value: _formatLakhs(data.revenueMtd),
        label: 'Revenue MTD',
        onTap: _openOrders,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((s) => SizedBox(width: cardWidth, child: _StatCard(data: s))).toList(),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(icon: Icons.people_alt, color: const Color(0xFF3D6BFF), label: 'Salesmen', onTap: _openSalesmen),
      _QuickAction(icon: Icons.near_me, color: const Color(0xFFDC2626), label: 'Live Track', onTap: _openLiveTracking),
      _QuickAction(icon: Icons.inventory_2, color: const Color(0xFF7C3AED), label: 'Orders', onTap: _openOrders),
      _QuickAction(icon: Icons.storefront, color: const Color(0xFF5B4FE9), label: 'Dealers', onTap: _openDealers),
      _QuickAction(icon: Icons.bar_chart, color: const Color(0xFF16A34A), label: 'Reports', onTap: _openReports),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((a) => Expanded(child: _QuickActionButton(action: a))).toList(),
      ),
    );
  }

  Widget _buildWeeklyChart(AdminOverview data) {
    final maxVal = data.weeklyActivity
        .map((d) => d.ordersCount > d.visitsCount ? d.ordersCount : d.visitsCount)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('This Week — Orders vs Visits', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              _legendDot(const Color(0xFF3D6BFF), 'Orders'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFB7C6FF), 'Visits'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: data.weeklyActivity.map((day) {
                final orderHeight = 90 * (day.ordersCount / maxVal);
                final visitHeight = 90 * (day.visitsCount / maxVal);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: orderHeight.clamp(4, 90).toDouble(),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D6BFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 8,
                          height: visitHeight.clamp(4, 90).toDouble(),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB7C6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEE').format(day.date),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _buildAttendanceDonut(AdminOverview data) {
    final total = data.presentToday + data.lateToday + data.absentToday;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _DonutPainter(
                present: data.presentToday,
                late: data.lateToday,
                absent: data.absentToday,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Attendance", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _attendanceRow(Colors.green, 'Present', data.presentToday),
                _attendanceRow(Colors.orange, 'Late', data.lateToday),
                _attendanceRow(Colors.red, 'Absent', data.absentToday),
                if (total == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('No salesmen yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceRow(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int present;
  final int late;
  final int absent;

  _DonutPainter({required this.present, required this.late, required this.absent});

  @override
  void paint(Canvas canvas, Size size) {
    final total = present + late + absent;
    final rect = Offset.zero & size;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 6.28319, false, bgPaint);

    if (total == 0) return;

    final segments = [
      [present, Colors.green],
      [late, Colors.orange],
      [absent, Colors.red],
    ];

    double startAngle = -1.5708; // -90 degrees, start at top
    for (final segment in segments) {
      final value = segment[0] as int;
      if (value == 0) continue;
      final color = segment[1] as Color;
      final sweep = (value / total) * 6.28319;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect.deflate(strokeWidth / 2), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.present != present || oldDelegate.late != late || oldDelegate.absent != absent;
  }
}

class _StatCardData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final VoidCallback? onTap;

  _StatCardData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: data.iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(data.icon, color: data.iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.iconColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  _QuickAction({required this.icon, required this.color, required this.label, required this.onTap});
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: action.color, shape: BoxShape.circle),
              child: Center(child: Icon(action.icon, color: Colors.white, size: 22)),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
