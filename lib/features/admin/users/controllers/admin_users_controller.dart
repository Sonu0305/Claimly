import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/admin_user_model.dart';

class AdminUsersState {
  final List<AdminUserModel> users;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String roleFilter; // 'all', 'customer', 'admin'

  const AdminUsersState({
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.roleFilter = 'all',
  });

  List<AdminUserModel> get filteredUsers {
    return users.where((u) {
      if (roleFilter != 'all' && u.role != roleFilter) return false;
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final nameMatch = (u.fullName ?? '').toLowerCase().contains(query);
        final phoneMatch = (u.phoneNumber ?? '').toLowerCase().contains(query);
        if (!nameMatch && !phoneMatch) return false;
      }
      return true;
    }).toList();
  }

  AdminUsersState copyWith({
    List<AdminUserModel>? users,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? roleFilter,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
    );
  }
}

class AdminUsersController extends StateNotifier<AdminUsersState> {
  final SupabaseClient _supabase;

  AdminUsersController(this._supabase) : super(const AdminUsersState(isLoading: true)) {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _supabase.from('profiles').select('''
        id, role, full_name, avatar_url, phone_number, created_at,
        products(id), claims(id)
      ''').order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(users: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void setRoleFilter(String role) => state = state.copyWith(roleFilter: role);
}

final adminUsersControllerProvider =
    StateNotifierProvider<AdminUsersController, AdminUsersState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminUsersController(supabase);
});

