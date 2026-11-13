import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../controllers/products_controller.dart';
import '../widgets/product_card.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  static const List<String> categories = [
    'All',
    'Electronics',
    'Home Appliances',
    'Automotive',
    'Furniture',
    'Other',
  ];

  static const List<String> statuses = [
    'All',
    'Active',
    'Expiring Soon',
    'Expired',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsControllerProvider);
    final controller = ref.read(productsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('product_add_fab'),
        onPressed: () => context.push('${RouteConstants.customerProducts}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadProducts(),
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('product_search_input'),
                onChanged: controller.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search products by name, brand, model...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => controller.setSearchQuery(''),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : AppColors.gray100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category & Status Filter Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...categories.map((cat) {
                    final isSelected = state.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        key: cat == 'All' ? const Key('product_filter_chip') : null,
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => controller.setSelectedCategory(cat),
                        selectedColor: AppColors.primary.withAlpha(40),
                        checkmarkColor: AppColors.primary,
                      ),
                    );
                  }),
                  const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                  ...statuses.map((stat) {
                    final isSelected = state.selectedStatus == stat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(stat),
                        selected: isSelected,
                        onSelected: (_) => controller.setSelectedStatus(stat),
                        selectedColor: AppColors.secondary.withAlpha(40),
                        checkmarkColor: AppColors.secondary,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Product List Body
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.products.isEmpty) {
                    return const LoadingIndicator(message: 'Loading products...');
                  }

                  if (state.errorMessage != null && state.products.isEmpty) {
                    return ErrorView(
                      message: state.errorMessage!,
                      onRetry: () => controller.loadProducts(),
                    );
                  }

                  final filtered = state.filteredProducts;

                  if (filtered.isEmpty) {
                    return EmptyState(
                      title: state.searchQuery.isNotEmpty || state.selectedCategory != 'All'
                          ? 'No matching products'
                          : 'No products registered yet',
                      message: state.searchQuery.isNotEmpty
                          ? 'Try adjusting your search terms or filters.'
                          : 'Register your electronics, appliances, and items to track warranties automatically.',
                      actionText: 'Register First Product',
                      onAction: () => context.push('${RouteConstants.customerProducts}/new'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(bottom: 80.0),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context.push('${RouteConstants.customerProducts}/${product.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

