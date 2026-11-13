import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../claims/repositories/claim_repository.dart';
import '../../products/repositories/product_repository.dart';
import '../models/dashboard_state.dart';

class DashboardController extends StateNotifier<DashboardState> {
  final ProductRepository _productRepo;
  final ClaimRepository _claimRepo;
  final String? _userId;

  DashboardController(this._productRepo, this._claimRepo, this._userId)
      : super(const DashboardState(isLoading: true)) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _productRepo.getProducts(userId: _userId),
        _claimRepo.fetchClaims(userId: _userId),
      ]);

      final products = results[0] as List<dynamic>;
      final claims = results[1] as List<dynamic>;

      state = state.copyWith(
        products: products.cast(),
        claims: claims.cast(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  final claimRepo = ref.watch(claimRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return DashboardController(productRepo, claimRepo, user?.id);
});

