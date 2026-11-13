import 'package:claimly/features/auth/models/user_model.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import 'package:claimly/features/customer/claims/models/claim_attachment_model.dart';
import 'package:claimly/features/customer/claims/models/claim_timeline_model.dart';
import 'package:claimly/features/customer/notifications/models/notification_model.dart';
import 'package:claimly/features/admin/dashboard/models/admin_analytics_model.dart';
import 'package:claimly/features/admin/users/models/admin_user_model.dart';

final sampleUserProfile = UserProfile(
  id: 'usr-customer-001',
  email: 'sarah.jenkins@claimly.com',
  role: UserRole.customer,
  fullName: 'Sarah Jenkins',
  avatarUrl: 'https://example.com/avatar.jpg',
  phoneNumber: '+15551234567',
  createdAt: DateTime(2025, 1, 15, 10, 0, 0),
  updatedAt: DateTime(2025, 1, 15, 10, 0, 0),
);

final sampleAdminProfile = UserProfile(
  id: 'usr-admin-999',
  email: 'admin@claimly.com',
  role: UserRole.admin,
  fullName: 'Alex Morgan',
  avatarUrl: null,
  phoneNumber: null,
  createdAt: DateTime(2025, 1, 1, 8, 0, 0),
  updatedAt: DateTime(2025, 1, 1, 8, 0, 0),
);

final sampleProduct = ProductModel(
  id: 'prod-001',
  userId: 'usr-customer-001',
  name: 'MacBook Pro 16" M3',
  category: 'Electronics',
  brand: 'Apple',
  modelNumber: 'A2991',
  serialNumber: 'C02XYZ123ABC',
  purchaseDate: DateTime(2025, 6, 1),
  warrantyPeriodMonths: 24,
  warrantyExpiryDate: DateTime(2027, 6, 1),
  receiptUrl: 'https://storage.example.com/receipts/prod-001.pdf',
  imageUrl: null,
  retailer: 'Apple Store Fifth Ave',
  notes: 'Space Gray 36GB RAM',
  price: 2499.00,
  createdAt: DateTime(2025, 6, 1, 12, 0, 0),
  updatedAt: DateTime(2025, 6, 1, 12, 0, 0),
);

final sampleAttachment = ClaimAttachmentModel(
  id: 'att-001',
  claimId: 'clm-001',
  fileUrl: 'https://storage.example.com/claims/defect.jpg',
  fileName: 'defect.jpg',
  fileType: 'image/jpeg',
  fileSize: 1048576, // 1 MB
  createdAt: DateTime(2026, 1, 10, 14, 0, 0),
);

final sampleTimeline = ClaimTimelineModel(
  id: 'tml-001',
  claimId: 'clm-001',
  fromStatus: 'draft',
  toStatus: 'submitted',
  changedBy: 'usr-customer-001',
  notes: 'Claim submitted by customer',
  createdAt: DateTime(2026, 1, 10, 14, 5, 0),
);

final sampleClaim = ClaimModel(
  id: 'clm-001',
  claimNumber: 'CLM-2026-0001',
  userId: 'usr-customer-001',
  productId: 'prod-001',
  type: 'warranty',
  status: 'submitted',
  title: 'Display flicker and artifacts',
  description: 'Screen randomly glitches with vertical colored lines.',
  issueCategory: 'Hardware Defect',
  incidentDate: DateTime(2026, 1, 8),
  priority: 85,
  adminNotes: null,
  resolutionNotes: null,
  resolvedAt: null,
  createdAt: DateTime(2026, 1, 10, 14, 0, 0),
  updatedAt: DateTime(2026, 1, 10, 14, 5, 0),
  product: sampleProduct,
  attachments: [sampleAttachment],
  timeline: [sampleTimeline],
);

final sampleNotification = NotificationModel(
  id: 'notif-001',
  userId: 'usr-customer-001',
  claimId: 'clm-001',
  type: 'claim_update',
  title: 'Claim Submitted',
  message: 'Your claim CLM-2026-0001 has been received and is being processed.',
  isRead: false,
  metadata: {'claim_number': 'CLM-2026-0001', 'status': 'submitted'},
  createdAt: DateTime(2026, 1, 10, 14, 6, 0),
);

const sampleAnalytics = AdminAnalyticsModel(
  summary: AnalyticsSummary(
    totalClaims: 120,
    activeClaims: 45,
    approvalRate: 82.5,
    avgResolutionDays: 4.2,
  ),
  statusBreakdown: {
    'submitted': 20,
    'under_review': 25,
    'approved': 60,
    'rejected': 15,
  },
  claimsByType: {
    'warranty': 80,
    'refund': 40,
  },
  submissionsLast30Days: [
    DailySubmission(date: '2026-01-01', count: 5),
    DailySubmission(date: '2026-01-02', count: 8),
  ],
  topIssueCategories: [
    IssueCategoryMetric(category: 'Hardware Defect', count: 45),
    IssueCategoryMetric(category: 'Battery Issue', count: 30),
  ],
);

final sampleAdminUser = AdminUserModel(
  id: 'usr-customer-001',
  role: 'customer',
  fullName: 'Sarah Jenkins',
  avatarUrl: 'https://example.com/avatar.jpg',
  phoneNumber: '+15551234567',
  createdAt: DateTime(2025, 1, 15, 10, 0, 0),
  productCount: 3,
  claimCount: 1,
);
