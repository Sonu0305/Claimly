/// Supabase backend configuration and storage bucket constants.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kvxfkfgzsapvvswjcmzj.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2eGZrZmd6c2FwdnZzd2pjbXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0MTA0MjIsImV4cCI6MjEwOTk4NjQyMn0.aONMvkR-_3u5XP8OaJJgpaihqjrwPGqcfy9ibOJbd7o',
  );

  // Storage Bucket Identifiers
  static const String receiptsBucket = 'receipts';
  static const String productImagesBucket = 'product-images';
  static const String claimAttachmentsBucket = 'claim-attachments';
  static const String avatarsBucket = 'avatars';

  // Realtime Channels
  static const String claimsChannel = 'public:claims';
  static const String timelineChannel = 'public:claim_timeline';
  static const String notificationsChannel = 'public:notifications';
}
