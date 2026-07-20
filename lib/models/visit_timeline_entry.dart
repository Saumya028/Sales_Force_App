/// One stop in a salesperson's "Today's Trail" timeline on the Admin
/// tracking detail screen — built from their `orders` rows (which
/// already record every visit outcome, not just completed orders) so
/// it reflects real visits rather than synthetic geofencing.
class VisitTimelineEntry {
  final String outletName;
  final DateTime time;
  final String outcome; // order_placed | no_order | follow_up
  final double? orderAmount;

  VisitTimelineEntry({
    required this.outletName,
    required this.time,
    required this.outcome,
    this.orderAmount,
  });
}
