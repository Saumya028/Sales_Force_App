import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_target.dart';
import '../services/target_service.dart';

const _orange = Color(0xFFEA8C00);

/// Salesman's "My Targets" screen — an orange overview header (overall %
/// ring + on-track/needs-attention counts) followed by filter chips and
/// a card per assigned target, all backed by real progress numbers from
/// [TargetService].
class MyTargetsScreen extends StatefulWidget {
  final String period; // 'YYYY-MM'

  const MyTargetsScreen({super.key, required this.period});

  @override
  State<MyTargetsScreen> createState() => _MyTargetsScreenState();
}

class _MyTargetsScreenState extends State<MyTargetsScreen> {
  final _targetService = TargetService();
  late Future<List<SalesTarget>> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _future = _targetService.getMyTargetsWithProgress(widget.period);
  }

  void _refresh() {
    setState(() {
      _future = _targetService.getMyTargetsWithProgress(widget.period);
    });
  }

  String get _periodLabel {
    final parts = widget.period.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<List<SalesTarget>>(
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
              final targets = snapshot.data ?? [];
              final filtered = _filter == 'All' ? targets : targets.where((t) => t.typeFilterLabel == _filter).toList();

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(targets),
                  const SizedBox(height: 14),
                  _buildFilterChips(targets),
                  const SizedBox(height: 4),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        child: filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    targets.isEmpty
                                        ? 'No targets assigned for $_periodLabel yet.'
                                        : 'No targets in this category.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: filtered.map((t) => _TargetCard(target: t)).toList(),
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

  Widget _buildHeader(List<SalesTarget> targets) {
    final onTrack = targets.where((t) => t.percent >= 80).length;
    final needsAttention = targets.where((t) => t.percent < 40).length;
    final overall = targets.isEmpty
        ? 0.0
        : targets.map((t) => t.percent.clamp(0, 100)).reduce((a, b) => a + b) / targets.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA84A), _orange],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('My Targets', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Text(_periodLabel, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(92, 92),
                      painter: _RingPainter(percent: overall),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${overall.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Overall', style: TextStyle(color: Colors.white, fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerStatRow('Targets Assigned', '${targets.length}'),
                    const SizedBox(height: 8),
                    _headerStatRow('On Track (≥80%)', '$onTrack'),
                    const SizedBox(height: 8),
                    _headerStatRow('Needs Attention', '$needsAttention'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFilterChips(List<SalesTarget> targets) {
    final categories = ['All', 'Value', 'Quantity', 'New Dealers', 'Products'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final selected = _filter == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: selected,
            onSelected: (_) => setState(() => _filter = cat),
            selectedColor: _orange,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: selected ? _orange : Colors.grey.shade300),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  _RingPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, 6.28319, false, bgPaint);

    final fraction = (percent / 100).clamp(0, 1).toDouble();
    if (fraction <= 0) return;

    final fgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(strokeWidth / 2), -1.5708, fraction * 6.28319, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.percent != percent;
}

class _TargetCard extends StatelessWidget {
  final SalesTarget target;
  const _TargetCard({required this.target});

  Color get _priorityColor {
    switch (target.priority) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'low':
        return const Color(0xFF16A34A);
      default:
        return _orange;
    }
  }

  Color get _percentColor {
    final p = target.percent;
    if (p >= 75) return const Color(0xFF16A34A);
    if (p >= 40) return _orange;
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: target.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(target.icon, color: target.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(target.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      target.priority.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _priorityColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Due: ${DateFormat('d MMM').format(target.dueDate)}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${target.percent.toStringAsFixed(0)}%',
                  style: TextStyle(color: _percentColor, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('achieved', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(target.achievedDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(target.goalDisplay, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_percentColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(target.remainingDisplay, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text(target.periodLabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          if (target.managerNote != null && target.managerNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      target.managerNote!,
                      style: const TextStyle(color: Color(0xFFB45309), fontSize: 12.5, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
