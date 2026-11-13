class NotificationModel {
  final String id;
  final String userId;
  final String? claimId;
  final String type; // 'warranty_expiry', 'claim_update', 'system'
  final String title;
  final String message;
  final bool isRead;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.claimId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.metadata = const {},
    required this.createdAt,
  });

  bool get isWarrantyExpiry => type == 'warranty_expiry';
  bool get isClaimUpdate => type == 'claim_update';
  bool get isSystem => type == 'system';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      claimId: json['claim_id'] as String?,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      metadata: json['metadata'] != null && json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    if (claimId != null) 'claim_id': claimId,
    'type': type,
    'title': title,
    'message': message,
    'is_read': isRead,
    'metadata': metadata,
    'created_at': createdAt.toIso8601String(),
  };

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? claimId,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      claimId: claimId ?? this.claimId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;
}

