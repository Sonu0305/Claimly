import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';

class ProductsState {
  final List<ProductModel> products;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCategory; // 'All' or category name
  final String selectedStatus; // 'All', 'Active', 'Expiring Soon', 'Expired'

  const ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.selectedStatus = 'All',
  });

  List<ProductModel> get filteredProducts {
    return products.where((product) {
      // Category filter
      if (selectedCategory != 'All' &&
          product.category.toLowerCase() != selectedCategory.toLowerCase()) {
        return false;
      }

      // Status filter
      if (selectedStatus != 'All') {
        final statusNorm = selectedStatus.toLowerCase();
        if (statusNorm == 'active' && !product.isActive) return false;
        if (statusNorm == 'expiring soon' && !product.isExpiringSoon) return false;
        if (statusNorm == 'expired' && !product.isExpired) return false;
      }

      // Search query filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final nameMatch = product.name.toLowerCase().contains(query);
        final brandMatch = (product.brand ?? '').toLowerCase().contains(query);
        final modelMatch = (product.modelNumber ?? '').toLowerCase().contains(query);
        final serialMatch = (product.serialNumber ?? '').toLowerCase().contains(query);
        if (!nameMatch && !brandMatch && !modelMatch && !serialMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  ProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? selectedCategory,
    String? selectedStatus,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }
}

class ProductsController extends StateNotifier<ProductsState> {
  final ProductRepository _repository;
  final String? _userId;

  ProductsController(this._repository, this._userId)
      : super(const ProductsState(isLoading: true)) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final products = await _repository.getProducts(userId: _userId);
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  Future<ProductModel> addProduct(ProductModel product) async {
    try {
      final created = await _repository.createProduct(product);
      state = state.copyWith(products: [created, ...state.products]);
      return created;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<ProductModel> updateProduct(ProductModel product) async {
    try {
      final updated = await _repository.updateProduct(product);
      final updatedList = state.products.map((p) => p.id == updated.id ? updated : p).toList();
      state = state.copyWith(products: updatedList);
      return updated;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      final updatedList = state.products.where((p) => p.id != id).toList();
      state = state.copyWith(products: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}

final productsControllerProvider =
    StateNotifierProvider<ProductsController, ProductsState>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return ProductsController(repo, user?.id);
});

