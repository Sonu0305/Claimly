/// Reusable static validation methods for text form fields and data entry.
class FormValidators {
  FormValidators._();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
  );

  static final RegExp _phoneRegExp = RegExp(
    r'^\+?[0-9\s\-()]{7,20}$',
  );

  /// Validates that a string is non-null and not empty after trimming.
  static String? requiredField(
    String? value, [
    String message = 'This field is required',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  /// Validates standard email address syntax.
  static String? email(
    String? value, [
    String message = 'Please enter a valid email address',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return message;
    }
    return null;
  }

  /// Validates password length and structure.
  static String? password(
    String? value, [
    int minLength = 6,
    String? message,
  ]) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return message ?? 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Validates confirmation password against the original password.
  static String? confirmPassword(
    String? value,
    String originalPassword, [
    String message = 'Passwords do not match',
  ]) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return message;
    }
    return null;
  }

  /// Validates positive numeric value (e.g. integers or counts).
  static String? positiveNumber(
    String? value, [
    String message = 'Please enter a valid positive number',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return 'Value is required';
    }
    final number = num.tryParse(value.trim());
    if (number == null || number <= 0) {
      return message;
    }
    return null;
  }

  /// Validates currency or monetary value (positive float > 0).
  static String? positiveCurrency(
    String? value, [
    String message = 'Please enter a valid amount greater than 0',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    final amount = double.tryParse(cleaned);
    if (amount == null || amount <= 0) {
      return message;
    }
    return null;
  }

  /// Validates phone number format.
  static String? phoneNumber(
    String? value, [
    String message = 'Please enter a valid phone number',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is often optional
    }
    if (!_phoneRegExp.hasMatch(value.trim())) {
      return message;
    }
    return null;
  }

  /// Validates product warranty period in months (between 1 and 120).
  static String? warrantyPeriod(
    String? value, [
    String message = 'Warranty period must be between 1 and 120 months',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return 'Warranty period is required';
    }
    final months = int.tryParse(value.trim());
    if (months == null || months < 1 || months > 120) {
      return message;
    }
    return null;
  }
}
