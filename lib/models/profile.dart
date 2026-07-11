class Profile {
  final String id;
  final String? fullName;
  final String role;

  Profile({required this.id, this.fullName, required this.role});

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      fullName: json['full_name'],
      role: json['role'] ?? 'salesperson',
    );
  }
}
