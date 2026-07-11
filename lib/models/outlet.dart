class Outlet {
  final String id;
  final String name;
  final String? address;
  final String? contactPerson;
  final String? contactNumber;

  Outlet({
    required this.id,
    required this.name,
    this.address,
    this.contactPerson,
    this.contactNumber,
  });

  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      contactPerson: json['contact_person'],
      contactNumber: json['contact_number'],
    );
  }

  /// Map used when inserting a brand-new outlet. `id` and
  /// `assigned_salesperson_id` are handled separately by the service
  /// (the DB generates the id; the service stamps the current user).
  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (contactPerson != null && contactPerson!.isNotEmpty)
        'contact_person': contactPerson,
      if (contactNumber != null && contactNumber!.isNotEmpty)
        'contact_number': contactNumber,
    };
  }
}
