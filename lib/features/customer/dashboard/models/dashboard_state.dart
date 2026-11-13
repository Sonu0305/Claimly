import '../../claims/models/claim_model.dart';
import '../../products/models/product_model.dart';

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final List<ProductModel> products;
  final List<ClaimModel> claims;

  const DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.products = const [],
    this.claims = const [],
  });

  int get activeWarrantiesCount =>
      products.where((p) => p.isActive || p.isExpiringSoon).length;

  int get pendingClaimsCount => claims.where((c) => c.isPending).length;

  int get approvedClaimsCount =>
      claims.where((c) => c.isApproved || c.isCompleted).length;

  int get expiringSoonCount =>
      products.where((p) => p.isExpiringSoon).length;

  List<ProductModel> get expiringSoonProducts {
    final list = products
        .where((p) => p.daysRemaining >= 0 && p.daysRemaining <= 30)
        .toList();
    list.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return list;
  }

  List<ClaimModel> get recentClaims {
    final list = List<ClaimModel>.from(claims);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(5).toList();
  }

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ProductModel>? products,
    List<ClaimModel>? claims,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      products: products ?? this.products,
      claims: claims ?? this.claims,
    );
  }
}

