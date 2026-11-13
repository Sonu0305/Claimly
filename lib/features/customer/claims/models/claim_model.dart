import '../../products/models/product_model.dart';
import 'claim_attachment_model.dart';
import 'claim_timeline_model.dart';

class ClaimModel {
  final String id;
  final String claimNumber;
  final String userId;
  final String productId;
  final String type; // 'warranty', 'refund', 'replacement'
  final String status; // 'draft', 'submitted', 'under_review', 'approved', 'rejected', 'completed'
  final String title;
  final String description;
  final String? issueCategory;
  final DateTime? incidentDate;
  final int priority;
  final String? adminNotes;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined relations
  final ProductModel? product;
  final List<ClaimAttachmentModel> attachments;
  final List<ClaimTimelineModel> timeline;

  const ClaimModel({
    required this.id,
    required this.claimNumber,
    required this.userId,
    required this.productId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    this.issueCategory,
    this.incidentDate,
    this.priority = 0,
    this.adminNotes,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.product,
    this.attachments = const [],
    this.timeline = const [],
  });

  String get claimType => type;
  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
  bool get isUnderReview => status == 'under_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';
  bool get isPending =>
      status == 'draft' || status == 'submitted' || status == 'under_review';

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    ProductModel? product;
    if (json['products'] != null && json['products'] is Map<String, dynamic>) {
      product = ProductModel.fromJson(json['products'] as Map<String, dynamic>);
    }

    List<ClaimAttachmentModel> attachments = [];
    if (json['claim_attachments'] != null && json['claim_attachments'] is List) {
      attachments = (json['claim_attachments'] as List)
          .map((a) => ClaimAttachmentModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    List<ClaimTimelineModel> timeline = [];
    if (json['claim_timeline'] != null && json['claim_timeline'] is List) {
      timeline = (json['claim_timeline'] as List)
          .map((t) => ClaimTimelineModel.fromJson(t as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return ClaimModel(
      id: json['id'] as String,
      claimNumber: json['claim_number'] as String? ?? 'CLM-PENDING',
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      type: json['type'] as String? ?? 'warranty',
      status: json['status'] as String? ?? 'submitted',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      issueCategory: json['issue_category'] as String?,
      incidentDate: json['incident_date'] != null
          ? DateTime.tryParse(json['incident_date'] as String)
          : null,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      adminNotes: json['admin_notes'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      product: product,
      attachments: attachments,
      timeline: timeline,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'claim_number': claimNumber,
    'user_id': userId,
    'product_id': productId,
    'type': type,
    'status': status,
    'title': title,
    'description': description,
    'issue_category': issueCategory,
    if (incidentDate != null)
      'incident_date': incidentDate!.toIso8601String().split('T')[0],
    'priority': priority,
    'admin_notes': adminNotes,
    'resolution_notes': resolutionNotes,
  };

  ClaimModel copyWith({
    String? status,
    int? priority,
    String? adminNotes,
    String? resolutionNotes,
    DateTime? resolvedAt,
    ProductModel? product,
    List<ClaimAttachmentModel>? attachments,
    List<ClaimTimelineModel>? timeline,
    DateTime? updatedAt,
  }) {
    return ClaimModel(
      id: id,
      claimNumber: claimNumber,
      userId: userId,
      productId: productId,
      type: type,
      status: status ?? this.status,
      title: title,
      description: description,
      issueCategory: issueCategory,
      incidentDate: incidentDate,
      priority: priority ?? this.priority,
      adminNotes: adminNotes ?? this.adminNotes,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      product: product ?? this.product,
      attachments: attachments ?? this.attachments,
      timeline: timeline ?? this.timeline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          claimNumber == other.claimNumber &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ claimNumber.hashCode ^ status.hashCode;
}

