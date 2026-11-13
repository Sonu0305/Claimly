import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';

class AdminClaimItem {
  final String id;
  final String claimNumber;
  final String userId;
  final String productId;
  final String type;
  final String status;
  final String title;
  final String description;
  final String? issueCategory;
  final DateTime? incidentDate;
  final int priority;
  final String? adminNotes;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? customerName;
  final String? customerAvatar;
  final String? productName;
  final String? productCategory;

  const AdminClaimItem({
    required this.id,
    required this.claimNumber,
    required this.userId,
    required this.productId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    this.issueCategory,
    this.incidentDate,
    required this.priority,
    this.adminNotes,
    this.resolutionNotes,
    this.resolvedAt,
    required this.createdAt,
    this.customerName,
    this.customerAvatar,
    this.productName,
    this.productCategory,
  });

  factory AdminClaimItem.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final product = json['products'] as Map<String, dynamic>?;

    return AdminClaimItem(
      id: json['id'] as String,
      claimNumber: json['claim_number'] as String? ?? 'CLM-PENDING',
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      type: json['type'] as String? ?? 'warranty',
      status: json['status'] as String? ?? 'submitted',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      issueCategory: json['issue_category'] as String?,
      incidentDate: json['incident_date'] != null
          ? DateTime.tryParse(json['incident_date'] as String)
          : null,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      adminNotes: json['admin_notes'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      customerName: profile?['full_name'] as String?,
      customerAvatar: profile?['avatar_url'] as String?,
      productName: product?['name'] as String?,
      productCategory: product?['category'] as String?,
    );
  }
}

class AdminClaimsState {
  final List<AdminClaimItem> claims;
  final bool isLoading;
  final String? errorMessage;
  final String selectedStatusFilter; // 'all', 'submitted', 'under_review', 'approved', 'rejected', 'completed'
  final String searchQuery;
  final bool sortByPriority;

  const AdminClaimsState({
    this.claims = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedStatusFilter = 'all',
    this.searchQuery = '',
    this.sortByPriority = false,
  });

  List<AdminClaimItem> get filteredClaims {
    return claims.where((c) {
      if (selectedStatusFilter != 'all' && c.status != selectedStatusFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchNumber = c.claimNumber.toLowerCase().contains(query);
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchCustomer = (c.customerName ?? '').toLowerCase().contains(query);
        if (!matchNumber && !matchTitle && !matchCustomer) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (sortByPriority) {
          final pComp = b.priority.compareTo(a.priority);
          if (pComp != 0) return pComp;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  AdminClaimsState copyWith({
    List<AdminClaimItem>? claims,
    bool? isLoading,
    String? errorMessage,
    String? selectedStatusFilter,
    String? searchQuery,
    bool? sortByPriority,
  }) {
    return AdminClaimsState(
      claims: claims ?? this.claims,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      sortByPriority: sortByPriority ?? this.sortByPriority,
    );
  }
}

class AdminClaimsController extends StateNotifier<AdminClaimsState> {
  final SupabaseClient _supabase;

  AdminClaimsController(this._supabase) : super(const AdminClaimsState(isLoading: true)) {
    fetchClaims();
  }

  Future<void> fetchClaims() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _supabase.from('claims').select('''
        id, claim_number, user_id, product_id, type, status, title, description,
        issue_category, incident_date, priority, admin_notes, resolution_notes,
        resolved_at, created_at,
        profiles:user_id(full_name, avatar_url),
        products:product_id(name, category)
      ''').order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((e) => AdminClaimItem.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(claims: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setStatusFilter(String filter) =>
      state = state.copyWith(selectedStatusFilter: filter);

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void togglePrioritySort() =>
      state = state.copyWith(sortByPriority: !state.sortByPriority);

  Future<void> updateClaimStatus({
    required String claimId,
    required String status,
    String? adminNotes,
    String? resolutionNotes,
    int? priority,
  }) async {
    final effectiveStatus = status == 'resolved' ? 'completed' : status;
    final payload = <String, dynamic>{
      'status': effectiveStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (adminNotes != null) payload['admin_notes'] = adminNotes;
    if (resolutionNotes != null) payload['resolution_notes'] = resolutionNotes;
    if (priority != null) payload['priority'] = priority;

    await _supabase.from('claims').update(payload).eq('id', claimId);
    await fetchClaims();
  }
}

final adminClaimsControllerProvider =
    StateNotifierProvider<AdminClaimsController, AdminClaimsState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminClaimsController(supabase);
});

