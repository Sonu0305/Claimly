import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/utils/warranty_calculator.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  group('ProductModel Tests', () {
    test('ProductModel constructor initializes correctly with all fields', () {
      final product = sampleProduct;

      expect(product.id, equals('prod-001'));
      expect(product.userId, equals('usr-customer-001'));
      expect(product.name, equals('MacBook Pro 16" M3'));
      expect(product.warrantyPeriodMonths, equals(24));
      expect(product.warrantyDurationMonths, equals(24));
      expect(product.productImageUrl, equals(product.imageUrl));
      expect(product.price, equals(2499.00));
    });

    test('ProductModel.fromJson parses standard payload', () {
      final json = {
        'id': 'prod-002',
        'user_id': 'usr-002',
        'name': 'Dell UltraSharp 32',
        'category': 'Electronics',
        'brand': 'Dell',
        'model_number': 'U3223QE',
        'serial_number': 'SN-998877',
        'purchase_date': '2024-03-15',
        'warranty_period_months': 36,
        'warranty_expiry_date': '2027-03-15',
        'receipt_url': 'https://example.com/receipt.pdf',
        'image_url': 'https://example.com/monitor.jpg',
        'retailer': 'Best Buy',
        'notes': '4K USB-C Monitor',
        'price': 899.99,
        'created_at': '2024-03-15T10:00:00.000Z',
        'updated_at': '2024-03-15T10:00:00.000Z',
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, equals('prod-002'));
      expect(product.name, equals('Dell UltraSharp 32'));
      expect(product.brand, equals('Dell'));
      expect(product.warrantyPeriodMonths, equals(36));
      expect(product.warrantyExpiryDate, equals(DateTime.parse('2027-03-15')));
      expect(product.price, equals(899.99));
    });

    test('ProductModel.fromJson calculates warrantyExpiryDate if omitted in JSON', () {
      final json = {
        'id': 'prod-003',
        'user_id': 'usr-003',
        'name': 'Bose QuietComfort 45',
        'category': 'Audio',
        'purchase_date': '2025-01-01',
        'warranty_period_months': 12,
      };

      final product = ProductModel.fromJson(json);

      expect(product.warrantyExpiryDate, equals(DateTime(2026, 1, 1)));
    });

    test('ProductModel.fromJson handles key aliases (model, product_image_url, warranty_duration_months)', () {
      final json = {
        'id': 'prod-004',
        'user_id': 'usr-004',
        'name': 'Logitech MX Master 3S',
        'category': 'Accessories',
        'purchase_date': '2024-06-01',
        'warranty_duration_months': 24,
        'model': 'MX-3S',
        'product_image_url': 'https://example.com/mouse.png',
      };

      final product = ProductModel.fromJson(json);

      expect(product.modelNumber, equals('MX-3S'));
      expect(product.imageUrl, equals('https://example.com/mouse.png'));
      expect(product.warrantyPeriodMonths, equals(24));
    });

    test('ProductModel.toJson formats dates properly in yyyy-MM-dd', () {
      final json = sampleProduct.toJson();

      expect(json['id'], equals('prod-001'));
      expect(json['purchase_date'], equals('2025-06-01'));
      expect(json['warranty_expiry_date'], equals('2027-06-01'));
      expect(json['retailer'], equals('Apple Store Fifth Ave'));
    });

    test('ProductModel dynamic warranty status getters behave correctly', () {
      final now = DateTime.now();

      // Active product (expiry far in future)
      final activeProduct = ProductModel(
        id: 'p-active',
        userId: 'u1',
        name: 'Active Phone',
        category: 'Electronics',
        purchaseDate: now.subtract(const Duration(days: 30)),
        warrantyPeriodMonths: 24,
        warrantyExpiryDate: now.add(const Duration(days: 365)),
        createdAt: now,
        updatedAt: now,
      );
      expect(activeProduct.status, equals(WarrantyStatus.active));
      expect(activeProduct.isActive, isTrue);
      expect(activeProduct.isExpired, isFalse);

      // Expiring soon product (e.g. 15 days remaining)
      final expiringProduct = ProductModel(
        id: 'p-expiring',
        userId: 'u1',
        name: 'Expiring Laptop',
        category: 'Electronics',
        purchaseDate: now.subtract(const Duration(days: 350)),
        warrantyPeriodMonths: 12,
        warrantyExpiryDate: now.add(const Duration(days: 15)),
        createdAt: now,
        updatedAt: now,
      );
      expect(expiringProduct.status, equals(WarrantyStatus.expiringSoon));
      expect(expiringProduct.isExpiringSoon, isTrue);

      // Expired product (e.g. 40 days ago)
      final expiredProduct = ProductModel(
        id: 'p-expired',
        userId: 'u1',
        name: 'Old Printer',
        category: 'Electronics',
        purchaseDate: now.subtract(const Duration(days: 400)),
        warrantyPeriodMonths: 12,
        warrantyExpiryDate: now.subtract(const Duration(days: 40)),
        createdAt: now,
        updatedAt: now,
      );
      expect(expiredProduct.status, equals(WarrantyStatus.expired));
      expect(expiredProduct.isExpired, isTrue);
    });
  });
}

