import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/features/auth/models/user_model.dart';
import '../../test_helpers/test_fixtures.dart';

void main() {
  group('UserModel & UserRole Tests', () {
    test('UserRole.fromString correctly parses role values and handles fallback', () {
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
      expect(UserRole.fromString('customer'), equals(UserRole.customer));
      expect(UserRole.fromString('CUSTOMER'), equals(UserRole.customer));
      expect(UserRole.fromString(null), equals(UserRole.customer));
      expect(UserRole.fromString('unknown_role'), equals(UserRole.customer));
    });

    test('UserProfile constructor assigns properties and computes role getters', () {
      final customer = sampleUserProfile;
      expect(customer.isCustomer, isTrue);
      expect(customer.isAdmin, isFalse);

      final admin = sampleAdminProfile;
      expect(admin.isAdmin, isTrue);
      expect(admin.isCustomer, isFalse);
    });

    test('UserProfile.fromJson correctly parses full JSON payload including timestamps', () {
      final json = {
        'id': 'usr-123',
        'email': 'john.doe@example.com',
        'role': 'admin',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'phone_number': '+1234567890',
        'created_at': '2025-02-01T12:00:00.000Z',
        'updated_at': '2025-02-02T15:30:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, equals('usr-123'));
      expect(profile.email, equals('john.doe@example.com'));
      expect(profile.role, equals(UserRole.admin));
      expect(profile.fullName, equals('John Doe'));
      expect(profile.avatarUrl, equals('https://example.com/avatar.png'));
      expect(profile.phoneNumber, equals('+1234567890'));
      expect(profile.createdAt, equals(DateTime.parse('2025-02-01T12:00:00.000Z')));
      expect(profile.updatedAt, equals(DateTime.parse('2025-02-02T15:30:00.000Z')));
    });

    test('UserProfile.toJson produces expected Map representation', () {
      final json = sampleUserProfile.toJson();

      expect(json['id'], equals('usr-customer-001'));
      expect(json['role'], equals('customer'));
      expect(json['full_name'], equals('Sarah Jenkins'));
      expect(json['avatar_url'], equals('https://example.com/avatar.jpg'));
      expect(json['phone_number'], equals('+15551234567'));
      expect(json['created_at'], isNotNull);
      expect(json['updated_at'], isNotNull);
    });

    test('UserProfile copyWith and value equality (== and hashCode)', () {
      final updated = sampleUserProfile.copyWith(
        fullName: 'Sarah M. Jenkins',
        phoneNumber: '+19998887777',
      );

      expect(updated.id, equals(sampleUserProfile.id));
      expect(updated.email, equals(sampleUserProfile.email));
      expect(updated.fullName, equals('Sarah M. Jenkins'));
      expect(updated.phoneNumber, equals('+19998887777'));
      expect(updated == sampleUserProfile, isFalse);

      final identicalProfile = UserProfile(
        id: sampleUserProfile.id,
        email: sampleUserProfile.email,
        role: sampleUserProfile.role,
        fullName: sampleUserProfile.fullName,
        avatarUrl: sampleUserProfile.avatarUrl,
        phoneNumber: sampleUserProfile.phoneNumber,
        createdAt: sampleUserProfile.createdAt,
        updatedAt: sampleUserProfile.updatedAt,
      );

      expect(identicalProfile == sampleUserProfile, isTrue);
      expect(identicalProfile.hashCode, equals(sampleUserProfile.hashCode));
    });
  });
}

