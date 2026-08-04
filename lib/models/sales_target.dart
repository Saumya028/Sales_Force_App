import 'package:flutter/material.dart';

/// A target assigned by an Admin to a salesperson for a given calendar
/// month ("period", stored as 'YYYY-MM').
///
/// `achievedValue` is NOT stored in the database — it's filled in on the
/// client by [AdminTargetService.getTargetsWithProgress] after aggregating
/// that month's real orders/order_items/outlets, so progress always
/// reflects live data rather than a stale cached number.
class SalesTarget {
  final String id;
  final String salespersonId;
  final String salespersonName;
  final String targetType; // value | quantity | new_dealer | product
  final String? productId;
  final String? productName;
  final double goalValue;
  final String period; // 'YYYY-MM'
  final String priority; // low | medium | high
  final String? managerNote;
  final DateTime createdAt;

  double achievedValue;

  SalesTarget({
    required this.id,
    required this.salespersonId,
    required this.salespersonName,
    required this.targetType,
    this.productId,
    this.productName,
    required this.goalValue,
    required this.period,
    this.priority = 'medium',
    this.managerNote,
    required this.createdAt,
    this.achievedValue = 0,
  });

  factory SalesTarget.fromJson(Map<String, dynamic> json) {
    return SalesTarget(
      id: json['id'],
      salespersonId: json['salesperson_id'],
      salespersonName:
          json['profiles'] != null ? (json['profiles']['full_name'] ?? 'Unnamed Salesman') : 'Unnamed Salesman',
      targetType: json['target_type'],
      productId: json['product_id'],
      productName: json['products'] != null ? json['products']['name'] : null,
      goalValue: (json['goal_value'] as num).toDouble(),
      period: json['period'],
      priority: json['priority'] ?? 'medium',
      managerNote: json['manager_note'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// Raw achievement percentage — can exceed 100 on overachievement.
  double get percent => goalValue <= 0 ? 0 : (achievedValue / goalValue) * 100;

  /// 0..1, safe to feed straight into a LinearProgressIndicator.
  double get progressFraction => goalValue <= 0 ? 0 : (achievedValue / goalValue).clamp(0, 1).toDouble();

  String get label {
    switch (targetType) {
      case 'value':
        return 'Monthly Revenue';
      case 'quantity':
        return 'Units Sold';
      case 'new_dealer':
        return 'New Dealer Onboarding';
      case 'product':
        return productName ?? 'Product Target';
      default:
        return 'Target';
    }
  }

  IconData get icon {
    switch (targetType) {
      case 'value':
        return Icons.show_chart;
      case 'quantity':
        return Icons.inventory_2_outlined;
      case 'new_dealer':
        return Icons.groups_outlined;
      case 'product':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  Color get color {
    switch (targetType) {
      case 'value':
        return const Color(0xFF3D6BFF);
      case 'quantity':
        return const Color(0xFF7C3AED);
      case 'new_dealer':
        return const Color(0xFF16A34A);
      case 'product':
        return const Color(0xFFEA8C00);
      default:
        return Colors.grey;
    }
  }

  /// e.g. "₹73,000 / ₹1,00,000" or "128 / 220 units" or "3 / 5 dealers".
  String formattedProgress() {
    if (targetType == 'value') {
      return '${_money(achievedValue)} / ${_money(goalValue)}';
    }
    final suffix = targetType == 'new_dealer' ? 'dealers' : 'units';
    return '${achievedValue.toStringAsFixed(0)} / ${goalValue.toStringAsFixed(0)} $suffix';
  }

  String get unitLabel {
    switch (targetType) {
      case 'new_dealer':
        return 'dealers';
      case 'value':
        return '';
      default:
        return 'units';
    }
  }

  /// e.g. "₹382k" or "142 units" or "2 dealers".
  String get achievedDisplay =>
      targetType == 'value' ? _money(achievedValue) : '${achievedValue.toStringAsFixed(0)} $unitLabel';

  /// e.g. "of ₹520k" or "of 245 units".
  String get goalDisplay =>
      targetType == 'value' ? 'of ${_money(goalValue)}' : 'of ${goalValue.toStringAsFixed(0)} $unitLabel';

  /// e.g. "₹138k remaining", "103 units remaining", or a completion message.
  String get remainingDisplay {
    final remaining = goalValue - achievedValue;
    if (remaining <= 0) return 'Goal achieved 🎉';
    return targetType == 'value' ? '${_money(remaining)} remaining' : '${remaining.toStringAsFixed(0)} $unitLabel remaining';
  }

  /// Last calendar day of this target's period, e.g. 31 Jul.
  DateTime get dueDate {
    final parts = period.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateTime(year, month + 1, 0);
  }

  /// e.g. "Jul 2025" — used as the small trailing label under the progress bar.
  String get periodLabel {
    final parts = period.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return '${_monthAbbrev(date.month)} ${date.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static String _monthAbbrev(int month) => _months[month - 1];

  /// e.g. "value" -> "Value", "new_dealer" -> "New Dealers", used for
  /// the salesman-side filter chips.
  String get typeFilterLabel {
    switch (targetType) {
      case 'value':
        return 'Value';
      case 'quantity':
        return 'Quantity';
      case 'new_dealer':
        return 'New Dealers';
      case 'product':
        return 'Products';
      default:
        return 'Other';
    }
  }

  String _money(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

