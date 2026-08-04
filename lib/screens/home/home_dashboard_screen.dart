import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/profile.dart';
import '../../models/outlet.dart';
import '../../models/sales_order.dart';
import '../../models/beat_plan.dart';
import '../../models/attendance.dart';
import '../../models/sales_target.dart';
import '../../services/profile_service.dart';
import '../../services/outlet_service.dart';
import '../../services/order_service.dart';
import '../../services/beat_plan_service.dart';
import '../../services/attendance_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/target_service.dart';
import '../add_outlet_screen.dart';
import '../outlet_picker_screen.dart';
import '../today_route_screen.dart';
import '../territory_screen.dart';
import '../notifications_screen.dart';
import '../my_targets_screen.dart';

/// The Salesman Home dashboard — first tab of the bottom nav.
/// Every element here reads real data from Supabase:
/// - Greeting + avatar come from the logged-in profile
/// - "Assigned Area" comes from today's `beat_plans` row (set by an Admin)
/// - The 4 stat cards are computed from today's orders/visits, all-time
///   pending follow-ups, and today's attendance record
/// - Quick Actions perform real actions (Start Shift, Add Dealer, Place
///   Order) or open a "Coming Soon" placeholder (View Route)
/// - "Today's Route" previews the same visited/pending data as the full
///   Today's Route screen (reachable via "View All")
class HomeDashboardScreen extends StatefulWidget {
  /// Lets this screen ask the bottom-nav shell to switch tabs (e.g. when a
  /// stat card is tapped).
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeData {
  final Profile profile;
  final List<Outlet> outlets;
  final List<SalesOrder> todayOrders;
  final int pendingFollowUps;
  final BeatPlan? beatPlan;
  final AttendanceRecord? attendance;
  final List<SalesTarget> targets;

  _HomeData({
    required this.profile,
    required this.outlets,
    required this.todayOrders,
    required this.pendingFollowUps,
    required this.beatPlan,
    required this.attendance,
    required this.targets,
  });

  int get visitedOutletCount => todayOrders.map((o) => o.outletId).toSet().length;
  int get ordersPlacedToday => todayOrders.where((o) => o.outcome == 'order_placed').length;
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _profileService = ProfileService();
  final _outletService = OutletService();
  final _orderService = OrderService();
  final _beatPlanService = BeatPlanService();
  final _attendanceService = AttendanceService();
  final _targetService = TargetService();

  late Future<_HomeData> _future;
  bool _startingShift = false;

  String get _currentPeriod {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      _profileService.getMyProfile(),
      _outletService.getMyOutlets(),
      _orderService.getTodayOrders(),
      _orderService.getPendingFollowUpsCount(),
      _beatPlanService.getTodayPlan(),
      _attendanceService.getTodayAttendance(),
      _targetService.getMyTargetsWithProgress(_currentPeriod),
    ]);
    return _HomeData(
      profile: results[0] as Profile,
      outlets: results[1] as List<Outlet>,
      todayOrders: results[2] as List<SalesOrder>,
      pendingFollowUps: results[3] as int,
      beatPlan: results[4] as BeatPlan?,
      attendance: results[5] as AttendanceRecord?,
      targets: results[6] as List<SalesTarget>,
    );
  }

  void _refresh() => setState(() {
        _future = _load();
      });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  Future<void> _startShift() async {
    setState(() => _startingShift = true);
    try {
      final record = await _attendanceService.checkIn();
      LocationTrackingService.instance.start();
      _refresh();
      if (mounted) {
        final already = record.checkInTime != null &&
            DateTime.now().difference(record.checkInTime!).inMinutes > 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(already
                ? 'Shift already started today.'
                : 'Shift started — you\'re marked present for today.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t start shift. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingShift = false);
    }
  }

  Future<void> _addDealer() async {
    final newOutlet = await Navigator.push<Outlet>(
      context,
      MaterialPageRoute(builder: (_) => const AddOutletScreen()),
    );
    if (newOutlet == null) return;
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newOutlet.name} added to your outlets')),
      );
    }
  }

  Future<void> _placeOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutletPickerScreen()),
    );
    _refresh();
  }

  void _viewRoute() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TerritoryScreen()))
        .then((_) => _refresh());
  }

  void _viewAllRoute() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayRouteScreen())).then((_) => _refresh());
  }

  void _viewAllTargets() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MyTargetsScreen(period: _currentPeriod)))
        .then((_) => _refresh());
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen(isAdmin: false)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<_HomeData>(
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
                  _buildHeader(context, data),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatsGrid(data),
                            const SizedBox(height: 16),
                            _buildQuickActions(),
                            const SizedBox(height: 16),
                            _buildTargetsCard(data),
                            const SizedBox(height: 16),
                            _buildTodayRoute(data),
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

  Widget _buildHeader(BuildContext context, _HomeData data) {
    final firstName = (data.profile.fullName ?? 'Salesperson').split(' ').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D6BFF), Color(0xFF1530A6)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.profile.fullName ?? 'Salesperson',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _openNotifications,
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  ),
                  if (data.pendingFollowUps > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => widget.onNavigateToTab?.call(4),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials(data.profile.fullName),
                    style: const TextStyle(color: Color(0xFF1530A6), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAssignedAreaCard(data),
        ],
      ),
    );
  }

  Widget _buildAssignedAreaCard(_HomeData data) {
    final plan = data.beatPlan;
    final dealerCount = data.outlets.length;

    String title;
    String subtitle;
    if (plan != null) {
      title = plan.zoneName;
      subtitle = plan.coverageKm != null
          ? '$dealerCount dealers · ${plan.coverageKm!.toStringAsFixed(1)} km coverage'
          : '$dealerCount dealers assigned';
    } else {
      title = 'No Area Assigned Yet';
      subtitle = dealerCount > 0
          ? 'Your manager hasn\'t assigned today\'s beat · $dealerCount dealers on your list'
          : 'Your manager hasn\'t assigned today\'s beat yet';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan != null ? 'Assigned Area: $title' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(_HomeData data) {
    final stats = [
      _StatCardData(
        icon: Icons.show_chart,
        iconColor: const Color(0xFF3D6BFF),
        iconBg: const Color(0xFFE7EDFF),
        value: '${data.visitedOutletCount}/${data.outlets.length}',
        label: "Today's Visits",
        onTap: () => widget.onNavigateToTab?.call(1),
      ),
      _StatCardData(
        icon: Icons.shopping_bag_outlined,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFE3F7EA),
        value: '${data.ordersPlacedToday}',
        label: 'Orders Placed',
        onTap: () => widget.onNavigateToTab?.call(2),
      ),
      _StatCardData(
        icon: Icons.error_outline,
        iconColor: const Color(0xFFEA8C00),
        iconBg: const Color(0xFFFFF1DC),
        value: '${data.pendingFollowUps}',
        label: 'Pending Follow Ups',
        onTap: () => widget.onNavigateToTab?.call(2),
      ),
      _StatCardData(
        icon: data.attendance != null ? Icons.check_circle_outline : Icons.schedule,
        iconColor: data.attendance != null ? const Color(0xFF16A34A) : Colors.grey,
        iconBg: data.attendance != null ? const Color(0xFFE3F7EA) : Colors.grey.shade200,
        value: data.attendance != null ? 'Present' : 'Not Started',
        label: 'Attendance',
        onTap: () => widget.onNavigateToTab?.call(3),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map((s) => SizedBox(width: cardWidth, child: _StatCard(data: s)))
              .toList(),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.access_time_filled,
        color: const Color(0xFF3D6BFF),
        label: 'Start Shift',
        onTap: _startingShift ? null : _startShift,
        loading: _startingShift,
      ),
      _QuickAction(
        icon: Icons.map_outlined,
        color: const Color(0xFF7C3AED),
        label: 'View Route',
        onTap: _viewRoute,
      ),
      _QuickAction(
        icon: Icons.add,
        color: const Color(0xFF16A34A),
        label: 'Add Dealer',
        onTap: _addDealer,
      ),
      _QuickAction(
        icon: Icons.shopping_bag,
        color: const Color(0xFFB026C4),
        label: 'Place Order',
        onTap: _placeOrder,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'QUICK ACTIONS',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: actions.map((a) => Expanded(child: _QuickActionButton(action: a))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetsCard(_HomeData data) {
    final monthName = DateFormat('MMMM').format(DateTime.now());
    final targets = data.targets;

    // Prefer one of each type, in this order, to fill up to 3 slots —
    // matches the mockup's Value / Quantity / New Dealers trio.
    const preferredOrder = ['value', 'quantity', 'new_dealer', 'product'];
    final shown = <SalesTarget>[];
    for (final type in preferredOrder) {
      final matches = targets.where((t) => t.targetType == type);
      if (matches.isNotEmpty) shown.add(matches.first);
      if (shown.length == 3) break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D6BFF), Color(0xFF1530A6)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$monthName Targets',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: _viewAllTargets,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600)),
                    const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No targets assigned yet this month.',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: shown
                  .map((t) => Expanded(child: _MiniTargetColumn(target: t)))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayRoute(_HomeData data) {
    final latestOrderByOutlet = <String, SalesOrder>{};
    for (final order in data.todayOrders) {
      latestOrderByOutlet.putIfAbsent(order.outletId, () => order);
    }
    final preview = data.outlets.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text("Today's Route", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: _viewAllRoute,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All', style: TextStyle(color: Color(0xFF3D6BFF), fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, color: Color(0xFF3D6BFF), size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No dealers assigned yet. Tap "Add Dealer" to get started.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...preview.map((outlet) {
              final order = latestOrderByOutlet[outlet.id];
              return _RoutePreviewRow(outlet: outlet, order: order);
            }),
        ],
      ),
    );
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
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
  final VoidCallback? onTap;
  final bool loading;

  _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.loading = false,
  });
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
              child: Center(
                child: action.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(action.icon, color: Colors.white, size: 22),
              ),
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

class _MiniTargetColumn extends StatelessWidget {
  final SalesTarget target;
  const _MiniTargetColumn({required this.target});

  String get _progressLabel {
    if (target.targetType == 'new_dealer') {
      return '${target.achievedValue.toStringAsFixed(0)} / ${target.goalValue.toStringAsFixed(0)}';
    }
    return target.formattedProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(target.typeFilterLabel,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(_progressLabel,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RoutePreviewRow extends StatelessWidget {
  final Outlet outlet;
  final SalesOrder? order;

  const _RoutePreviewRow({required this.outlet, required this.order});

  @override
  Widget build(BuildContext context) {
    final visited = order != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: visited ? Colors.green : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  visited ? DateFormat('h:mm a').format(order!.createdAt.toLocal()) : 'Not visited yet',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: visited ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  visited ? 'VISITED' : 'PENDING',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: visited ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                visited && order!.totalAmount > 0 ? '₹${order!.totalAmount.toStringAsFixed(0)}' : '–',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
