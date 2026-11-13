import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/customer/claims/models/claim_model.dart';
import 'package:claimly/features/customer/claims/models/claim_attachment_model.dart';
import 'package:claimly/features/customer/claims/models/claim_timeline_model.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  group('ClaimModel & Nested Entities Tests', () {
    test('ClaimModel constructor initializes correctly with default priority', () {
      final claim = ClaimModel(
        id: 'c-new',
        claimNumber: 'CLM-PENDING',
        userId: 'u1',
        productId: 'p1',
        type: 'warranty',
        status: 'draft',
        title: 'Draft claim',
        description: 'Issue description',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(claim.priority, equals(0));
      expect(claim.attachments, isEmpty);
      expect(claim.timeline, isEmpty);
      expect(claim.claimType, equals('warranty'));
    });

    test('ClaimModel status helper getters evaluate correctly', () {
      final baseNow = DateTime.now();

      ClaimModel withStatus(String s) => ClaimModel(
        id: 'c',
        claimNumber: 'CLM',
        userId: 'u',
        productId: 'p',
        type: 'warranty',
        status: s,
        title: 'T',
        description: 'D',
        createdAt: baseNow,
        updatedAt: baseNow,
      );

      expect(withStatus('draft').isDraft, isTrue);
      expect(withStatus('draft').isPending, isTrue);

      expect(withStatus('submitted').isSubmitted, isTrue);
      expect(withStatus('submitted').isPending, isTrue);

      expect(withStatus('under_review').isUnderReview, isTrue);
      expect(withStatus('under_review').isPending, isTrue);

      expect(withStatus('approved').isApproved, isTrue);
      expect(withStatus('approved').isPending, isFalse);

      expect(withStatus('rejected').isRejected, isTrue);
      expect(withStatus('rejected').isPending, isFalse);

      expect(withStatus('completed').isCompleted, isTrue);
      expect(withStatus('completed').isPending, isFalse);
    });

    test('ClaimModel.fromJson parses nested relations (products, claim_attachments, claim_timeline)', () {
      final json = {
        'id': 'clm-100',
        'claim_number': 'CLM-2026-0099',
        'user_id': 'usr-1',
        'product_id': 'prod-1',
        'type': 'refund',
        'status': 'submitted',
        'title': 'Defective device',
        'description': 'Device stopped working',
        'issue_category': 'Hardware Defect',
        'incident_date': '2026-01-05',
        'priority': 75,
        'created_at': '2026-01-06T10:00:00.000Z',
        'updated_at': '2026-01-06T10:00:00.000Z',
        'products': {
          'id': 'prod-1',
          'user_id': 'usr-1',
          'name': 'iPad Pro',
          'category': 'Electronics',
          'purchase_date': '2025-05-01',
          'warranty_period_months': 12,
          'warranty_expiry_date': '2026-05-01',
          'created_at': '2025-05-01T00:00:00.000Z',
          'updated_at': '2025-05-01T00:00:00.000Z',
        },
        'claim_attachments': [
          {
            'id': 'att-100',
            'claim_id': 'clm-100',
            'file_url': 'https://example.com/photo.jpg',
            'file_name': 'photo.jpg',
            'file_type': 'image/jpeg',
            'file_size': 2048,
            'created_at': '2026-01-06T10:01:00.000Z',
          }
        ],
        'claim_timeline': [
          {
            'id': 'tml-2',
            'claim_id': 'clm-100',
            'from_status': 'draft',
            'to_status': 'submitted',
            'created_at': '2026-01-06T10:02:00.000Z',
          },
          {
            'id': 'tml-1',
            'claim_id': 'clm-100',
            'to_status': 'draft',
            'created_at': '2026-01-06T10:00:00.000Z',
          }
        ],
      };

      final claim = ClaimModel.fromJson(json);

      expect(claim.id, equals('clm-100'));
      expect(claim.claimNumber, equals('CLM-2026-0099'));
      expect(claim.product, isNotNull);
      expect(claim.product!.name, equals('iPad Pro'));
      expect(claim.attachments.length, equals(1));
      expect(claim.attachments.first.fileName, equals('photo.jpg'));
      // Timeline should be sorted by createdAt ascending
      expect(claim.timeline.length, equals(2));
      expect(claim.timeline[0].id, equals('tml-1'));
      expect(claim.timeline[1].id, equals('tml-2'));
    });

    test('ClaimModel.toJson formats incident_date and serializes fields', () {
      final json = sampleClaim.toJson();

      expect(json['id'], equals('clm-001'));
      expect(json['claim_number'], equals('CLM-2026-0001'));
      expect(json['type'], equals('warranty'));
      expect(json['status'], equals('submitted'));
      expect(json['incident_date'], equals('2026-01-08'));
      expect(json['priority'], equals(85));
    });

    test('ClaimAttachmentModel fromJson, toJson, and getters (isImage, isPdf, formattedSize)', () {
      final imageAtt = sampleAttachment;
      expect(imageAtt.isImage, isTrue);
      expect(imageAtt.isPdf, isFalse);
      expect(imageAtt.formattedSize, equals('1.0 MB'));

      final pdfAtt = ClaimAttachmentModel(
        id: 'att-pdf',
        claimId: 'clm-1',
        fileUrl: 'https://example.com/invoice.pdf',
        fileName: 'invoice.pdf',
        fileType: 'application/pdf',
        fileSize: 512,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(pdfAtt.isPdf, isTrue);
      expect(pdfAtt.isImage, isFalse);
      expect(pdfAtt.formattedSize, equals('512 B'));

      final kbAtt = ClaimAttachmentModel(
        id: 'att-kb',
        claimId: 'clm-1',
        fileUrl: 'https://example.com/doc.txt',
        fileName: 'doc.txt',
        fileSize: 4096,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(kbAtt.formattedSize, equals('4.0 KB'));

      final json = imageAtt.toJson();
      expect(json['id'], equals('att-001'));
      expect(json['file_name'], equals('defect.jpg'));
    });

    test('ClaimTimelineModel fromJson, toJson, and value equality', () {
      final timeline = sampleTimeline;
      final json = timeline.toJson();

      expect(json['id'], equals('tml-001'));
      expect(json['from_status'], equals('draft'));
      expect(json['to_status'], equals('submitted'));

      final parsed = ClaimTimelineModel.fromJson(json);
      expect(parsed.id, equals(timeline.id));
      expect(parsed.claimId, equals(timeline.claimId));
      expect(parsed.toStatus, equals(timeline.toStatus));
      expect(parsed == timeline, isTrue);
      expect(parsed.hashCode, equals(timeline.hashCode));
    });
  });
}

