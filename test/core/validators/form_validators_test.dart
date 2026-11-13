import 'package:flutter_test/flutter_test.dart';
import 'package:claimly/core/validators/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('requiredField validates non-empty strings', () {
      expect(FormValidators.requiredField('Valid Name'), isNull);
      expect(FormValidators.requiredField(''), 'This field is required');
      expect(FormValidators.requiredField('   '), 'This field is required');
      expect(FormValidators.requiredField(null), 'This field is required');
      expect(FormValidators.requiredField('', 'Custom required msg'), 'Custom required msg');
    });

    test('email validates valid and rejects invalid email syntax', () {
      expect(FormValidators.email('test@example.com'), isNull);
      expect(FormValidators.email('first.last@claimly.co.uk'), isNull);
      expect(FormValidators.email(''), 'Email is required');
      expect(FormValidators.email(null), 'Email is required');
      expect(FormValidators.email('invalid-email'), 'Please enter a valid email address');
      expect(FormValidators.email('test@'), 'Please enter a valid email address');
      expect(FormValidators.email('@example.com'), 'Please enter a valid email address');
    });

    test('password validates minimum character length', () {
      expect(FormValidators.password('secret123'), isNull);
      expect(FormValidators.password('123456'), isNull);
      expect(FormValidators.password('12345'), 'Password must be at least 6 characters');
      expect(FormValidators.password(''), 'Password is required');
      expect(FormValidators.password(null), 'Password is required');
      expect(FormValidators.password('123', 8, 'Min 8 chars'), 'Min 8 chars');
    });

    test('confirmPassword matches against target password', () {
      expect(FormValidators.confirmPassword('secret', 'secret'), isNull);
      expect(FormValidators.confirmPassword('secret1', 'secret2'), 'Passwords do not match');
      expect(FormValidators.confirmPassword('', 'secret'), 'Please confirm your password');
      expect(FormValidators.confirmPassword(null, 'secret'), 'Please confirm your password');
    });

    test('positiveNumber validates numeric input strictly greater than zero', () {
      expect(FormValidators.positiveNumber('5'), isNull);
      expect(FormValidators.positiveNumber('100.5'), isNull);
      expect(FormValidators.positiveNumber('0'), 'Please enter a valid positive number');
      expect(FormValidators.positiveNumber('-10'), 'Please enter a valid positive number');
      expect(FormValidators.positiveNumber('abc'), 'Please enter a valid positive number');
      expect(FormValidators.positiveNumber(''), 'Value is required');
    });

    test('positiveCurrency validates valid monetary amounts', () {
      expect(FormValidators.positiveCurrency('\$99.99'), isNull);
      expect(FormValidators.positiveCurrency('150.00'), isNull);
      expect(FormValidators.positiveCurrency('0.00'), 'Please enter a valid amount greater than 0');
      expect(FormValidators.positiveCurrency('-\$15.00'), 'Please enter a valid amount greater than 0');
      expect(FormValidators.positiveCurrency(''), 'Amount is required');
    });

    test('phoneNumber validates phone formatting when provided', () {
      expect(FormValidators.phoneNumber('+1234567890'), isNull);
      expect(FormValidators.phoneNumber('123-456-7890'), isNull);
      expect(FormValidators.phoneNumber('(123) 456-7890'), isNull);
      expect(FormValidators.phoneNumber(''), isNull); // Optional
      expect(FormValidators.phoneNumber(null), isNull); // Optional
      expect(FormValidators.phoneNumber('123'), 'Please enter a valid phone number');
      expect(FormValidators.phoneNumber('abc-def-ghij'), 'Please enter a valid phone number');
    });

    test('warrantyPeriod validates range between 1 and 120 months', () {
      expect(FormValidators.warrantyPeriod('1'), isNull);
      expect(FormValidators.warrantyPeriod('12'), isNull);
      expect(FormValidators.warrantyPeriod('120'), isNull);
      expect(FormValidators.warrantyPeriod('0'), 'Warranty period must be between 1 and 120 months');
      expect(FormValidators.warrantyPeriod('121'), 'Warranty period must be between 1 and 120 months');
      expect(FormValidators.warrantyPeriod('invalid'), 'Warranty period must be between 1 and 120 months');
      expect(FormValidators.warrantyPeriod(''), 'Warranty period is required');
    });
  });
}
