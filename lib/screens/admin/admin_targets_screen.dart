import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/profile.dart';
import '../../models/product.dart';
import '../../models/sales_target.dart';
import '../../services/admin_target_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/product_service.dart';
import 'assign_target_screen.dart';

const _orange = Color(0xFFEA8C00);

/// Admin's "Target Management" hub — pick a month, see team performance
/// at a glance, and drill into each salesman's targets. Assigning a new
/// target routes to [AssignTargetScreen].
class AdminTargetsScreen extends StatefulWidget {
  const AdminTargetsScreen({super.key});

  @override
  State<AdminTargetsScreen> createState() => _AdminTargetsScreenState();
}

class _AdminTargetsScreenState extends State<AdminTargetsScreen> {
  final _targetService = AdminTargetService();
  final _userService = AdminUserService();
  final _productService = ProductService();

  late List<String> _periods; // 3 months: prev, current, next — 'YYYY-MM'
  late String _selectedPeriod;

  List<Profile> _salesmen = [];
  List<Product> _products = [];
  Future<List<SalesTarget>>? _targetsFuture;
  bool _loadingRoster = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periods = [
      _fmt(DateTime(now.year, now.month - 1)),
      _fmt(DateTime(now.year, now.month)),
      _fmt(DateTime(now.year, now.month + 1)),
    ];
    _selectedPeriod = _periods[1];
    _loadRoster();
    _refreshTargets();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _periodLabel(String period) {
    final parts = period.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMM yyyy').format(date);
  }

  Future<void> _loadRoster() async {
    try {
      final results = await Future.wait([
        _userService.getAllSalesmen(),
        _productService.getAllProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _salesmen = (results[0] as List<Profile>).where((p) => p.isActive).toList();
        _products = results[1] as List<Product>;
        _loadingRoster = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  void _refreshTargets() {
    setState(() {
      _targetsFuture = _targetService.getTargetsWithProgress(_selectedPeriod);
    });
  }

  void _selectPeriod(String period) {
    if (period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
    _refreshTargets();
  }

  Future<void> _openAssignTarget([Profile? preselected]) async {
    if (_loadingRoster || _salesmen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active salesmen to assign targets to yet.')),
      );
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignTargetScreen(
          salesmen: _salesmen,
          products: _products,
          initialPeriod: _selectedPeriod,
          availablePeriods: _periods,
          preselectedSalesman: preselected,
        ),
      ),
    );
    if (created == true) {
      _refreshTargets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target assigned.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Target Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton.icon(
                onPressed: () => _openAssignTarget(),
                style: FilledButton.styleFrom(backgroundColor: _orange),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Assign Target'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadRoster();
            _refreshTargets();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildMonthTabs(),
              const SizedBox(height: 14),
              FutureBuilder<List<SalesTarget>>(
                future: _targetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }
                  final targets = snapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTeamPerformanceBanner(targets),
                      const SizedBox(height: 16),
                      ..._buildSalesmanCards(targets),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthTabs() {
    return Row(
      children: _periods.map((p) {
        final selected = p == _selectedPeriod;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _selectPeriod(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _orange : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: selected ? _orange : Colors.grey.shade300),
                ),
                child: Text(
                  _periodLabel(p),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeamPerformanceBanner(List<SalesTarget> targets) {
    final grouped = _groupBySalesman(targets);
    final avgs = grouped.values.map(_averagePercent).toList();
    final teamAvg = avgs.isEmpty ? 0.0 : avgs.reduce((a, b) => a + b) / avgs.length;
    final onTrack = avgs.where((a) => a >= 75).length;
    final atRisk = avgs.where((a) => a < 40).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA84A), _orange],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Performance · ${_periodLabel(_selectedPeriod)}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Row(
            children: [
              _bannerStat('${teamAvg.toStringAsFixed(0)}%', 'Team Avg'),
              _bannerStat('$onTrack', 'On Track'),
              _bannerStat('$atRisk', 'At Risk'),
              _bannerStat('${targets.length}', 'Targets'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
        ],
      ),
    );
  }

  Map<String, List<SalesTarget>> _groupBySalesman(List<SalesTarget> targets) {
    final map = <String, List<SalesTarget>>{};
    for (final t in targets) {
      map.putIfAbsent(t.salespersonId, () => []).add(t);
    }
    return map;
  }

  double _averagePercent(List<SalesTarget> targets) {
    if (targets.isEmpty) return 0;
    final sum = targets.map((t) => t.percent.clamp(0, 100)).reduce((a, b) => a + b);
    return sum / targets.length;
  }

  List<Widget> _buildSalesmanCards(List<SalesTarget> targets) {
    final grouped = _groupBySalesman(targets);

    if (_salesmen.isEmpty && !_loadingRoster) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: Text('No active salesmen yet.')),
        ),
      ];
    }

    // Salesmen with targets first (sorted by avg % desc), then salesmen
    // with none yet — so the roster is always visible, not just those
    // already assigned something.
    final withTargets = _salesmen.where((s) => grouped.containsKey(s.id)).toList()
      ..sort((a, b) => _averagePercent(grouped[b.id]!).compareTo(_averagePercent(grouped[a.id]!)));
    final withoutTargets = _salesmen.where((s) => !grouped.containsKey(s.id)).toList();

    return [
      ...withTargets.map((s) => _SalesmanTargetCard(
            profile: s,
            targets: grouped[s.id]!,
            avgPercent: _averagePercent(grouped[s.id]!),
            onAddTarget: () => _openAssignTarget(s),
          )),
      ...withoutTargets.map((s) => _SalesmanTargetCard(
            profile: s,
            targets: const [],
            avgPercent: 0,
            onAddTarget: () => _openAssignTarget(s),
          )),
    ];
  }
}

class _SalesmanTargetCard extends StatelessWidget {
  final Profile profile;
  final List<SalesTarget> targets;
  final double avgPercent;
  final VoidCallback onAddTarget;

  const _SalesmanTargetCard({
    required this.profile,
    required this.targets,
    required this.avgPercent,
    required this.onAddTarget,
  });

  Color get _percentColor {
    if (avgPercent >= 75) return const Color(0xFF16A34A);
    if (avgPercent >= 40) return _orange;
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final shown = targets.take(3).toList();
    final more = targets.length - shown.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE7EDFF),
                child: const Icon(Icons.person, color: Color(0xFF3D6BFF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName ?? 'Unnamed Salesman',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(empCode(profile.id), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              if (targets.isNotEmpty)
                Text('${avgPercent.toStringAsFixed(0)}%',
                    style: TextStyle(color: _percentColor, fontSize: 20, fontWeight: FontWeight.bold))
              else
                TextButton.icon(
                  onPressed: onAddTarget,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Target'),
                  style: TextButton.styleFrom(foregroundColor: _orange),
                ),
            ],
          ),
          if (targets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (avgPercent / 100).clamp(0, 1).toDouble(),
                minHeight: 7,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(_percentColor),
              ),
            ),
            const SizedBox(height: 12),
            ...shown.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(t.icon, size: 15, color: t.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                      Text('${t.percent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            if (more > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+$more more target${more > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddTarget,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Target'),
                style: TextButton.styleFrom(foregroundColor: _orange, padding: EdgeInsets.zero),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
