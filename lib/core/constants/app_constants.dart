/// Application-wide constants and configuration values.
class AppConstants {
  AppConstants._();

  static const String appName = 'Claimly';
  static const String appTagline = 'Automated Warranty & Refund Claim Assistant';

  // Storage & Preference Keys
  static const String themeModeKey = 'theme_mode';
  static const String authTokenKey = 'auth_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';

  // Warranty Defaults & Thresholds
  static const int defaultWarrantyMonths = 12;
  static const int expiryWarningThresholdDays = 30;
  static const int expiryCriticalThresholdDays = 7;
  static const int expiryImmediateThresholdDays = 1;
  static const int warrantyGracePeriodDays = 7;

  // File & Upload Limits
  static const int maxAttachmentSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const int maxAttachmentsPerClaim = 5;
  static const List<String> allowedFileExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  // Pagination & Polling
  static const int defaultPageSize = 20;
  static const Duration splashDelay = Duration(milliseconds: 1500);
}
