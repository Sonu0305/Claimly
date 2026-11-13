import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/admin/dashboard/models/admin_analytics_model.dart';
import 'package:claimly/features/admin/users/models/admin_user_model.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  group('Admin Models Tests', () {
    test('AnalyticsSummary fromJson and toJson', () {
      final json = {
        'total_claims': 50,
        'active_claims': 20,
        'approval_rate': 75.5,
        'avg_resolution_days': 3.5,
      };

      final summary = AnalyticsSummary.fromJson(json);

      expect(summary.totalClaims, equals(50));
      expect(summary.activeClaims, equals(20));
      expect(summary.approvalRate, equals(75.5));
      expect(summary.avgResolutionDays, equals(3.5));

      final serialized = summary.toJson();
      expect(serialized['total_claims'], equals(50));
      expect(serialized['approval_rate'], equals(75.5));
    });

    test('DailySubmission and IssueCategoryMetric serialization', () {
      const daily = DailySubmission(date: '2026-01-15', count: 12);
      expect(daily.toJson(), equals({'date': '2026-01-15', 'count': 12}));

      final parsedDaily = DailySubmission.fromJson({'date': '2026-01-20', 'count': 9});
      expect(parsedDaily.date, equals('2026-01-20'));
      expect(parsedDaily.count, equals(9));

      const metric = IssueCategoryMetric(category: 'Screen Cracked', count: 18);
      expect(metric.toJson(), equals({'category': 'Screen Cracked', 'count': 18}));

      final parsedMetric = IssueCategoryMetric.fromJson({'category': 'Software Bug', 'count': 7});
      expect(parsedMetric.category, equals('Software Bug'));
      expect(parsedMetric.count, equals(7));
    });

    test('AdminAnalyticsModel fromJson parses nested objects and computes convenience getters', () {
      final json = {
        'summary': {
          'total_claims': 100,
          'active_claims': 40,
          'approval_rate': 80.0,
          'avg_resolution_days': 5.0,
        },
        'status_breakdown': {
          'submitted': 15,
          'under_review': 25,
          'approved': 45,
          'rejected': 10,
          'completed': 5,
        },
        'claims_by_type': {
          'warranty': 70,
          'refund': 30,
        },
        'submissions_last_30_days': [
          {'date': '2026-01-01', 'count': 3},
        ],
        'top_issue_categories': [
          {'category': 'Hardware Defect', 'count': 25},
        ],
      };

      final model = AdminAnalyticsModel.fromJson(json);

      expect(model.totalClaims, equals(100));
      expect(model.activeClaims, equals(40));
      expect(model.pendingClaims, equals(40)); // 15 submitted + 25 under_review
      expect(model.approvedClaims, equals(45));
      expect(model.rejectedClaims, equals(10));
      expect(model.completedClaims, equals(5));
      expect(model.approvalRate, equals(80.0));
      expect(model.avgResolutionDays, equals(5.0));
      expect(model.submissionsLast30Days.length, equals(1));
      expect(model.topIssueCategories.first.category, equals('Hardware Defect'));
    });

    test('AdminAnalyticsModel toJson outputs complete payload', () {
      const model = sampleAnalytics;
      final json = model.toJson();

      expect(json['summary'], isNotNull);
      expect(json['status_breakdown']['approved'], equals(60));
      expect(json['claims_by_type']['warranty'], equals(80));
      expect(json['claims_over_time'].length, equals(2));
      expect(json['top_issue_categories'].length, equals(2));
    });

    test('AdminUserModel fromJson calculates productCount and claimCount from array lengths', () {
      final json = {
        'id': 'usr-admin-user',
        'role': 'customer',
        'full_name': 'David Miller',
        'avatar_url': 'https://example.com/david.jpg',
        'phone_number': '+123456789',
        'created_at': '2025-05-10T08:00:00.000Z',
        'products': [
          {'id': 'p1'},
          {'id': 'p2'},
        ],
        'claims': [
          {'id': 'c1'},
        ],
      };

      final user = AdminUserModel.fromJson(json);

      expect(user.id, equals('usr-admin-user'));
      expect(user.fullName, equals('David Miller'));
      expect(user.isAdmin, isFalse);
      expect(user.productCount, equals(2));
      expect(user.claimCount, equals(1));
    });
  });
}
