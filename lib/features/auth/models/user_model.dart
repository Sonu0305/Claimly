enum UserRole {
  customer,
  admin;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.customer;
    final normalized = role.toLowerCase().trim();
    if (normalized == 'admin') return UserRole.admin;
    return UserRole.customer;
  }
}

class UserProfile {
  final String id;
  final String email;
  final UserRole role;
  final String? fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isCustomer => role == UserRole.customer;

  factory UserProfile.fromJson(Map<String, dynamic> json, {String? email}) {
    final roleStr = json['role'] as String?;
    return UserProfile(
      id: json['id'] as String,
      email: email ?? (json['email'] as String? ?? ''),
      role: UserRole.fromString(roleStr),
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'phone_number': phoneNumber,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  UserProfile copyWith({
    String? email,
    UserRole? role,
    String? fullName,
    String? avatarUrl,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          role == other.role &&
          fullName == other.fullName &&
          avatarUrl == other.avatarUrl &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      role.hashCode ^
      fullName.hashCode ^
      avatarUrl.hashCode ^
      phoneNumber.hashCode;
}
