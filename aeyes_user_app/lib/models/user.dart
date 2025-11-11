class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? role; // 'user' or 'guardian'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'user_id': id,
      'email': email,
      'name': name,
      'phone': phone ?? '',
      'address': address ?? '',
      'role': role ?? 'user',
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Create from Firestore document
  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      role: map['role'],
      createdAt: map['created_at']?.toDate(),
      updatedAt: map['updated_at']?.toDate(),
    );
  }

  // Copy with method for updates
  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? role,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 