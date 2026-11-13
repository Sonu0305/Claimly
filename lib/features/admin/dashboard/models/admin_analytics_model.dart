class AnalyticsSummary {
  final int totalClaims;
  final int activeClaims;
  final double approvalRate;
  final double avgResolutionDays;

  const AnalyticsSummary({
    required this.totalClaims,
    required this.activeClaims,
    required this.approvalRate,
    required this.avgResolutionDays,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalClaims: (json['total_claims'] as num?)?.toInt() ?? 0,
      activeClaims: (json['active_claims'] as num?)?.toInt() ?? 0,
      approvalRate: (json['approval_rate'] as num?)?.toDouble() ?? 0.0,
      avgResolutionDays: (json['avg_resolution_days'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_claims': totalClaims,
    'active_claims': activeClaims,
    'approval_rate': approvalRate,
    'avg_resolution_days': avgResolutionDays,
  };
}

class DailySubmission {
  final String date;
  final int count;

  const DailySubmission({required this.date, required this.count});

  factory DailySubmission.fromJson(Map<String, dynamic> json) {
    return DailySubmission(
      date: json['date'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'count': count};
}

class IssueCategoryMetric {
  final String category;
  final int count;

  const IssueCategoryMetric({required this.category, required this.count});

  factory IssueCategoryMetric.fromJson(Map<String, dynamic> json) {
    return IssueCategoryMetric(
      category: json['category'] as String? ?? 'General / Other',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'category': category, 'count': count};
}

class AdminAnalyticsModel {
  final AnalyticsSummary summary;
  final Map<String, int> statusBreakdown;
  final Map<String, int> claimsByType;
  final List<DailySubmission> submissionsLast30Days;
  final List<IssueCategoryMetric> topIssueCategories;

  const AdminAnalyticsModel({
    required this.summary,
    required this.statusBreakdown,
    required this.claimsByType,
    required this.submissionsLast30Days,
    required this.topIssueCategories,
  });

  // Convenience Getters
  int get totalClaims => summary.totalClaims;
  int get activeClaims => summary.activeClaims;
  int get pendingClaims =>
      (statusBreakdown['under_review'] ?? 0) + (statusBreakdown['submitted'] ?? 0);
  int get approvedClaims => statusBreakdown['approved'] ?? 0;
  int get rejectedClaims => statusBreakdown['rejected'] ?? 0;
  int get completedClaims => statusBreakdown['completed'] ?? 0;
  Map<String, int> get claimsByStatus => statusBreakdown;
  double get approvalRate => summary.approvalRate;
  double get avgResolutionDays => summary.avgResolutionDays;

  factory AdminAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] != null && json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    final summary = AnalyticsSummary.fromJson(summaryJson);

    final statusRaw = json['status_breakdown'] != null && json['status_breakdown'] is Map<String, dynamic>
        ? json['status_breakdown'] as Map<String, dynamic>
        : <String, dynamic>{};
    final statusBreakdown = statusRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final typeRaw = json['claims_by_type'] != null && json['claims_by_type'] is Map<String, dynamic>
        ? json['claims_by_type'] as Map<String, dynamic>
        : <String, dynamic>{};
    final claimsByType = typeRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final timeRaw = (json['claims_over_time'] ?? json['submissions_last_30_days']) as List<dynamic>? ?? [];
    final submissions = timeRaw
        .map((e) => DailySubmission.fromJson(e as Map<String, dynamic>))
        .toList();

    final issuesRaw = json['top_issue_categories'] as List<dynamic>? ?? [];
    final issues = issuesRaw
        .map((e) => IssueCategoryMetric.fromJson(e as Map<String, dynamic>))
        .toList();

    return AdminAnalyticsModel(
      summary: summary,
      statusBreakdown: statusBreakdown,
      claimsByType: claimsByType,
      submissionsLast30Days: submissions,
      topIssueCategories: issues,
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary.toJson(),
    'status_breakdown': statusBreakdown,
    'claims_by_type': claimsByType,
    'claims_over_time': submissionsLast30Days.map((e) => e.toJson()).toList(),
    'top_issue_categories': topIssueCategories.map((e) => e.toJson()).toList(),
  };
}

