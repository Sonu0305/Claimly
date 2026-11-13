class ClaimAttachmentModel {
  final String id;
  final String claimId;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;

  const ClaimAttachmentModel({
    required this.id,
    required this.claimId,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.createdAt,
  });

  bool get isImage =>
      fileType?.startsWith('image/') == true ||
      fileName.endsWith('.jpg') ||
      fileName.endsWith('.jpeg') ||
      fileName.endsWith('.png') ||
      fileName.endsWith('.webp');

  bool get isPdf =>
      fileType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf');

  String get formattedSize {
    if (fileSize == null) return 'Unknown size';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ClaimAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ClaimAttachmentModel(
      id: json['id'] as String,
      claimId: json['claim_id'] as String,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'claim_id': claimId,
    'file_url': fileUrl,
    'file_name': fileName,
    'file_type': fileType,
    'file_size': fileSize,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimAttachmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          claimId == other.claimId &&
          fileUrl == other.fileUrl;

  @override
  int get hashCode => id.hashCode ^ claimId.hashCode ^ fileUrl.hashCode;
}

