class ClaimTimelineModel {
  final String id;
  final String claimId;
  final String? fromStatus;
  final String toStatus;
  final String? changedBy;
  final String? notes;
  final DateTime createdAt;

  const ClaimTimelineModel({
    required this.id,
    required this.claimId,
    this.fromStatus,
    required this.toStatus,
    this.changedBy,
    this.notes,
    required this.createdAt,
  });

  factory ClaimTimelineModel.fromJson(Map<String, dynamic> json) {
    return ClaimTimelineModel(
      id: json['id'] as String,
      claimId: json['claim_id'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String? ?? 'submitted',
      changedBy: json['changed_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'claim_id': claimId,
    'from_status': fromStatus,
    'to_status': toStatus,
    'changed_by': changedBy,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimTimelineModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          claimId == other.claimId &&
          toStatus == other.toStatus;

  @override
  int get hashCode => id.hashCode ^ claimId.hashCode ^ toStatus.hashCode;
}

