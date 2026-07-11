class Profile {
  final String id;
  final String? fullName;
  final String role;
  final String status; // active | inactive

  Profile({
    required this.id,
    this.fullName,
    required this.role,
    this.status = 'active',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      fullName: json['full_name'],
      role: json['role'] ?? 'salesperson',
      status: json['status'] ?? 'active',
    );
  }

  bool get isActive => status == 'active';
}
