import '../../../../core/utils/warranty_calculator.dart';

class ProductModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String? brand;
  final String? modelNumber;
  final String? serialNumber;
  final DateTime purchaseDate;
  final int warrantyPeriodMonths;
  final DateTime warrantyExpiryDate;
  final String? receiptUrl;
  final String? imageUrl;
  final String? retailer;
  final String? notes;
  final double? price;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.brand,
    this.modelNumber,
    this.serialNumber,
    required this.purchaseDate,
    required this.warrantyPeriodMonths,
    required this.warrantyExpiryDate,
    this.receiptUrl,
    this.imageUrl,
    this.retailer,
    this.notes,
    this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  // Dynamic getters for dual-naming and domain compatibility
  int get warrantyDurationMonths => warrantyPeriodMonths;
  String? get productImageUrl => imageUrl;
  int get daysRemaining => WarrantyCalculator.calculateDaysRemaining(warrantyExpiryDate);
  WarrantyStatus get status => WarrantyCalculator.calculateStatusFromExpiry(warrantyExpiryDate);
  bool get isExpiringSoon => status == WarrantyStatus.expiringSoon;
  bool get isExpired => status == WarrantyStatus.expired;
  bool get isActive => status == WarrantyStatus.active;
  bool get isWithinGracePeriod => WarrantyCalculator.isWithinGracePeriod(warrantyExpiryDate);

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final purchaseDateParsed = DateTime.parse(json['purchase_date'] as String);
    final warrantyMonths = (json['warranty_period_months'] ?? json['warranty_duration_months'] ?? 12) as int;

    DateTime expiryDateParsed;
    if (json['warranty_expiry_date'] != null) {
      expiryDateParsed = DateTime.parse(json['warranty_expiry_date'] as String);
    } else {
      expiryDateParsed = WarrantyCalculator.calculateExpiryDate(purchaseDateParsed, warrantyMonths);
    }

    return ProductModel(
      id: json['id'] as String,
      userId: (json['user_id'] ?? '') as String,
      name: json['name'] as String,
      category: json['category'] as String,
      brand: json['brand'] as String?,
      modelNumber: (json['model_number'] ?? json['model']) as String?,
      serialNumber: json['serial_number'] as String?,
      purchaseDate: purchaseDateParsed,
      warrantyPeriodMonths: warrantyMonths,
      warrantyExpiryDate: expiryDateParsed,
      receiptUrl: json['receipt_url'] as String?,
      imageUrl: (json['image_url'] ?? json['product_image_url']) as String?,
      retailer: json['retailer'] as String?,
      notes: json['notes'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category,
    'brand': brand,
    'model_number': modelNumber,
    'serial_number': serialNumber,
    'purchase_date': purchaseDate.toIso8601String().split('T')[0],
    'warranty_period_months': warrantyPeriodMonths,
    'warranty_expiry_date': warrantyExpiryDate.toIso8601String().split('T')[0],
    'receipt_url': receiptUrl,
    'image_url': imageUrl,
    'retailer': retailer,
    'notes': notes,
  };

  ProductModel copyWith({
    String? name,
    String? category,
    String? brand,
    String? modelNumber,
    String? serialNumber,
    DateTime? purchaseDate,
    int? warrantyPeriodMonths,
    DateTime? warrantyExpiryDate,
    String? receiptUrl,
    String? imageUrl,
    String? retailer,
    String? notes,
    double? price,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyPeriodMonths: warrantyPeriodMonths ?? this.warrantyPeriodMonths,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      retailer: retailer ?? this.retailer,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          category == other.category &&
          brand == other.brand &&
          modelNumber == other.modelNumber &&
          serialNumber == other.serialNumber &&
          purchaseDate == other.purchaseDate &&
          warrantyPeriodMonths == other.warrantyPeriodMonths &&
          warrantyExpiryDate == other.warrantyExpiryDate &&
          receiptUrl == other.receiptUrl &&
          imageUrl == other.imageUrl &&
          retailer == other.retailer &&
          notes == other.notes;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      name.hashCode ^
      category.hashCode ^
      purchaseDate.hashCode ^
      warrantyExpiryDate.hashCode;
}
