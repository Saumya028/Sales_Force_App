import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/profile.dart';
import '../../models/product.dart';
import '../../models/sales_target.dart';
import '../../services/admin_target_service.dart';

const _orange = Color(0xFFEA8C00);

class _TargetTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  _TargetTypeOption(this.value, this.label, this.icon, this.color);
}

final _targetTypes = [
  _TargetTypeOption('value', 'Value Target', Icons.show_chart, const Color(0xFF3D6BFF)),
  _TargetTypeOption('quantity', 'Quantity Target', Icons.inventory_2_outlined, const Color(0xFF7C3AED)),
  _TargetTypeOption('new_dealer', 'New Dealer Target', Icons.groups_outlined, const Color(0xFF16A34A)),
  _TargetTypeOption('product', 'Product Target', Icons.shopping_bag_outlined, _orange),
];

/// Admin picks: 1) a salesman, 2) a target type (+ product, if that
/// type), 3) the goal amount, period, priority, and an optional note.
/// Pops `true` if a target was actually created.
class AssignTargetScreen extends StatefulWidget {
  final List<Profile> salesmen;
  final List<Product> products;
  final String initialPeriod;
  final List<String> availablePeriods; // 'YYYY-MM'
  final Profile? preselectedSalesman;

  const AssignTargetScreen({
    super.key,
    required this.salesmen,
    required this.products,
    required this.initialPeriod,
    required this.availablePeriods,
    this.preselectedSalesman,
  });

  @override
  State<AssignTargetScreen> createState() => _AssignTargetScreenState();
}

class _AssignTargetScreenState extends State<AssignTargetScreen> {
  final _targetService = AdminTargetService();
  final _goalController = TextEditingController();
  final _noteController = TextEditingController();

  Profile? _selectedSalesman;
  String? _selectedType;
  Product? _selectedProduct;
  late String _period;
  String _priority = 'medium';
  bool _saving = false;

  Future<List<SalesTarget>>? _currentTargetsFuture;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    if (widget.preselectedSalesman != null) {
      _selectedSalesman = widget.preselectedSalesman;
      _loadCurrentTargets();
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadCurrentTargets() {
    final salesman = _selectedSalesman;
    if (salesman == null) return;
    setState(() {
      _currentTargetsFuture = _targetService.getTargetsForSalespersonWithProgress(
        salespersonId: salesman.id,
        period: _period,
      );
    });
  }

  void _selectSalesman(Profile p) {
    setState(() => _selectedSalesman = p);
    _loadCurrentTargets();
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
      if (type != 'product') _selectedProduct = null;
    });
  }

  String get _goalLabel {
    switch (_selectedType) {
      case 'value':
        return 'rupees';
      case 'new_dealer':
        return 'dealers';
      default:
        return 'units';
    }
  }

  bool get _canSubmit {
    if (_selectedSalesman == null || _selectedType == null || _saving) return false;
    if (_selectedType == 'product' && _selectedProduct == null) return false;
    final goal = double.tryParse(_goalController.text.trim());
    return goal != null && goal > 0;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    try {
      await _targetService.assignTarget(
        salespersonId: _selectedSalesman!.id,
        targetType: _selectedType!,
        productId: _selectedType == 'product' ? _selectedProduct!.id : null,
        goalValue: double.parse(_goalController.text.trim()),
        period: _period,
        priority: _priority,
        managerNote: _noteController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign target: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _periodLabel(String period) {
    final parts = period.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Assign Target', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _sectionHeader('1', 'SELECT SALESMAN'),
            const SizedBox(height: 10),
            ...widget.salesmen.map((p) => _SalesmanTile(
                  profile: p,
                  selected: _selectedSalesman?.id == p.id,
                  onTap: () => _selectSalesman(p),
                )),
            if (_selectedSalesman != null) ...[
              const SizedBox(height: 12),
              _buildCurrentTargetsBox(),
            ],
            const SizedBox(height: 20),
            _sectionHeader('2', 'TARGET TYPE'),
            const SizedBox(height: 10),
            _buildTargetTypeGrid(),
            if (_selectedType == 'product') ...[
              const SizedBox(height: 12),
              _buildProductPicker(),
            ],
            const SizedBox(height: 20),
            _sectionHeader('3', 'SET GOAL & DETAILS'),
            const SizedBox(height: 10),
            _buildGoalField(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildPeriodDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildPriorityDropdown()),
              ],
            ),
            const SizedBox(height: 12),
            _buildNoteField(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.star_outline, size: 18),
                  label: const Text('Assign Target'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
          child: Center(
            child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTargetsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: FutureBuilder<List<SalesTarget>>(
        future: _currentTargetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final targets = snapshot.data ?? [];
          final name = _selectedSalesman?.fullName ?? 'Salesman';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name — Current Targets (${targets.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1530A6)),
              ),
              const SizedBox(height: 8),
              if (targets.isEmpty)
                Text('No targets assigned yet for ${_periodLabel(_period)}.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ...targets.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 15, color: t.color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.label, style: const TextStyle(fontSize: 13))),
                        Text(
                          '${t.percent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _percentColor(t.percent)),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Color _percentColor(double percent) {
    if (percent >= 75) return const Color(0xFF16A34A);
    if (percent >= 40) return _orange;
    return const Color(0xFFDC2626);
  }

  Widget _buildTargetTypeGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: _targetTypes.map((opt) {
        final selected = _selectedType == opt.value;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectType(opt.value),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? opt.color.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? opt.color : Colors.grey.shade200, width: selected ? 1.6 : 1),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(opt.icon, color: opt.color, size: 22),
                const SizedBox(height: 6),
                Text(
                  opt.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? opt.color : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Product>(
          isExpanded: true,
          hint: const Text('Choose a product'),
          value: _selectedProduct,
          items: widget.products
              .map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (p) => setState(() => _selectedProduct = p),
        ),
      ),
    );
  }

  Widget _buildGoalField() {
    return TextField(
      controller: _goalController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixText: _selectedType == 'value' ? '₹ ' : null,
        hintText: _selectedType == 'value' ? 'e.g. 500000' : 'e.g. 200',
        suffixText: _goalLabel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _period,
          items: widget.availablePeriods
              .map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p))))
              .toList(),
          onChanged: (p) {
            if (p == null) return;
            setState(() => _period = p);
            _loadCurrentTargets();
          },
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _priority,
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'high', child: Text('High')),
          ],
          onChanged: (p) => setState(() => _priority = p ?? 'medium'),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "Manager's note to salesman (optional)...",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _SalesmanTile extends StatelessWidget {
  final Profile profile;
  final bool selected;
  final VoidCallback onTap;

  const _SalesmanTile({required this.profile, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _orange : Colors.grey.shade200, width: selected ? 1.6 : 1),
          ),
          child: Row(
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(empCode(profile.id), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? _orange : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Derives a stable, display-only "EMP-NNNN" code from a profile's UUID,
/// same trick used elsewhere in the app for order numbers — the schema
/// only stores a UUID, no separate employee-code column.
String empCode(String id) {
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  final tag = (digits.isNotEmpty ? digits : id.hashCode.abs().toString()).padLeft(4, '0');
  return 'EMP-${tag.substring(tag.length - 4)}';
}
