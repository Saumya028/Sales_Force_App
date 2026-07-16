/// A reusable, named area of shops (e.g. "Fort, Mumbai"), created once
/// by an Admin. Shops belong to a route directly (see Outlet.routeId);
/// a salesperson sees only the shops on whichever route they're
/// currently assigned to (see Profile.currentRouteId).
class SalesRoute {
  final String id;
  final String name;
  final DateTime createdAt;

  SalesRoute({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory SalesRoute.fromJson(Map<String, dynamic> json) {
    return SalesRoute(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
