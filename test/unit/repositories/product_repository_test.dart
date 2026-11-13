import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/features/customer/products/repositories/product_repository.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late ProductRepositoryImpl repository;

  setUpAll(() {
    registerCommonFallbackValues();
  });

  setUp(() {
    mockSupabase = MockSupabaseClient();
    repository = ProductRepositoryImpl(mockSupabase);
  });

  group('ProductRepositoryImpl Tests', () {
    test('getProducts returns mapped ProductModel list', () async {
      when(() => mockSupabase.from('products')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder([sampleProduct.toJson()]),
      );

      final products = await repository.getProducts(userId: 'usr-customer-001');

      expect(products.length, equals(1));
      expect(products.first.id, equals(sampleProduct.id));
      expect(products.first.name, equals(sampleProduct.name));
    });

    test('getProductById returns single product', () async {
      when(() => mockSupabase.from('products')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(sampleProduct.toJson()),
      );

      final product = await repository.getProductById('prod-001');

      expect(product.id, equals('prod-001'));
      expect(product.name, equals(sampleProduct.name));
      expect(product.brand, equals('Apple'));
    });

    test('createProduct strips id and inserts clean payload', () async {
      when(() => mockSupabase.from('products')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(sampleProduct.toJson()),
      );

      final created = await repository.createProduct(sampleProduct);

      expect(created.id, equals(sampleProduct.id));
      expect(created.name, equals(sampleProduct.name));
    });

    test('deleteProduct deletes record by id', () async {
      when(() => mockSupabase.from('products')).thenAnswer(
        (_) => FakeSupabaseQueryBuilder(null),
      );

      await expectLater(
        repository.deleteProduct('prod-001'),
        completes,
      );
    });
  });
}
