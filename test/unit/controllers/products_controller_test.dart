import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/customer/products/controllers/products_controller.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockProductRepository mockProductRepo;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockProductRepo = MockProductRepository();
  });

  group('ProductsController Tests', () {
    test('loadProducts fetches and stores product list in state', () async {
      when(() => mockProductRepo.getProducts(userId: 'usr-customer-001'))
          .thenAnswer((_) async => [sampleProduct]);

      final controller = ProductsController(mockProductRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.products.length, equals(1));
      expect(controller.state.products.first.name, equals(sampleProduct.name));
    });

    test('setSearchQuery filters products case-insensitively across name, brand, model', () async {
      final product1 = sampleProduct; // MacBook Pro, Apple, A2991
      final product2 = ProductModel(
        id: 'prod-002',
        userId: 'usr-customer-001',
        name: 'Galaxy Tab S9',
        category: 'Electronics',
        brand: 'Samsung',
        modelNumber: 'SM-X710',
        purchaseDate: DateTime(2025, 2, 1),
        warrantyPeriodMonths: 12,
        warrantyExpiryDate: DateTime(2026, 2, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenAnswer((_) async => [product1, product2]);

      final controller = ProductsController(mockProductRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      // Search by brand "samsung"
      controller.setSearchQuery('samsung');
      expect(controller.state.filteredProducts.length, equals(1));
      expect(controller.state.filteredProducts.first.name, equals('Galaxy Tab S9'));

      // Search by model number "A2991"
      controller.setSearchQuery('a2991');
      expect(controller.state.filteredProducts.length, equals(1));
      expect(controller.state.filteredProducts.first.name, equals('MacBook Pro 16" M3'));

      // Empty query returns all
      controller.setSearchQuery('');
      expect(controller.state.filteredProducts.length, equals(2));
    });

    test('setSelectedCategory and setSelectedStatus filter product list', () async {
      final now = DateTime.now();
      final activeProduct = sampleProduct; // category: Electronics, active
      final appliancesProduct = ProductModel(
        id: 'prod-003',
        userId: 'usr-customer-001',
        name: 'Dyson V15',
        category: 'Home Appliances',
        brand: 'Dyson',
        purchaseDate: now.subtract(const Duration(days: 400)),
        warrantyPeriodMonths: 12,
        warrantyExpiryDate: now.subtract(const Duration(days: 35)), // expired
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenAnswer((_) async => [activeProduct, appliancesProduct]);

      final controller = ProductsController(mockProductRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      // Filter by category
      controller.setSelectedCategory('Home Appliances');
      expect(controller.state.filteredProducts.length, equals(1));
      expect(controller.state.filteredProducts.first.name, equals('Dyson V15'));

      // Reset category and filter by status
      controller.setSelectedCategory('All');
      controller.setSelectedStatus('Expired');
      expect(controller.state.filteredProducts.length, equals(1));
      expect(controller.state.filteredProducts.first.name, equals('Dyson V15'));
    });

    test('addProduct and deleteProduct update local state list', () async {
      when(() => mockProductRepo.getProducts(userId: any(named: 'userId')))
          .thenAnswer((_) async => [sampleProduct]);

      final controller = ProductsController(mockProductRepo, 'usr-customer-001');
      await Future<void>.delayed(Duration.zero);

      final newProduct = ProductModel(
        id: 'prod-new',
        userId: 'usr-customer-001',
        name: 'Sony Headphones',
        category: 'Audio',
        purchaseDate: DateTime(2025, 3, 1),
        warrantyPeriodMonths: 12,
        warrantyExpiryDate: DateTime(2026, 3, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => mockProductRepo.createProduct(newProduct))
          .thenAnswer((_) async => newProduct);
      when(() => mockProductRepo.deleteProduct('prod-001'))
          .thenAnswer((_) async {});

      // Add product
      await controller.addProduct(newProduct);
      expect(controller.state.products.length, equals(2));
      expect(controller.state.products.first.id, equals('prod-new'));

      // Delete product
      await controller.deleteProduct('prod-001');
      expect(controller.state.products.length, equals(1));
      expect(controller.state.products.any((p) => p.id == 'prod-001'), isFalse);
    });
  });
}

