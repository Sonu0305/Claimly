class AdminUserModel {
  final String id;
  final String role; // 'customer' or 'admin'
  final String? fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final DateTime createdAt;
  final int productCount;
  final int claimCount;

  const AdminUserModel({
    required this.id,
    required this.role,
    this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    required this.createdAt,
    this.productCount = 0,
    this.claimCount = 0,
  });

  bool get isAdmin => role == 'admin';

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final products = json['products'] as List<dynamic>? ?? [];
    final claims = json['claims'] as List<dynamic>? ?? [];

    return AdminUserModel(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'customer',
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      productCount: products.length,
      claimCount: claims.length,
    );
  }
}

