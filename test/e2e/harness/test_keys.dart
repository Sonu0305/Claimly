/// Standard semantic opaque UI Keys for Claimly Opaque-Box E2E Testing.
///
/// These keys decouple tests from internal widget implementations while
/// providing predictable identifiers for UI automation and assertions.
class TestKey {
  final String value;
  const TestKey(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestKey &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TestKey("$value")';
}

abstract class TestKeys {
  // Authentication & Session
  static const emailInput = TestKey('auth_email_input');
  static const passwordInput = TestKey('auth_password_input');
  static const confirmPasswordInput = TestKey('auth_confirm_password_input');
  static const fullNameInput = TestKey('auth_fullname_input');
  static const loginSubmitBtn = TestKey('auth_login_submit_btn');
  static const registerSubmitBtn = TestKey('auth_register_submit_btn');
  static const forgotPasswordBtn = TestKey('auth_forgot_password_btn');
  static const resetPasswordSubmitBtn = TestKey('auth_reset_password_submit_btn');
  static const logoutBtn = TestKey('auth_logout_btn');

  // Customer Navigation & Shell
  static const navHome = TestKey('nav_item_home');
  static const navProducts = TestKey('nav_item_products');
  static const navClaims = TestKey('nav_item_claims');
  static const navNotifications = TestKey('nav_item_notifications');
  static const navProfile = TestKey('nav_item_profile');
  static const unreadBadge = TestKey('nav_unread_badge');

  // Products
  static const addProductFab = TestKey('product_add_fab');
  static const productNameInput = TestKey('product_name_input');
  static const productCategoryDropdown = TestKey('product_category_dropdown');
  static const productBrandInput = TestKey('product_brand_input');
  static const productModelInput = TestKey('product_model_input');
  static const productSerialInput = TestKey('product_serial_input');
  static const productPurchaseDateInput = TestKey('product_purchase_date_input');
  static const productWarrantyMonthsInput = TestKey('product_warranty_months_input');
  static const productRetailerInput = TestKey('product_retailer_input');
  static const productSaveBtn = TestKey('product_save_btn');
  static const productDeleteBtn = TestKey('product_delete_btn');
  static const productSearchInput = TestKey('product_search_input');
  static const productFilterChip = TestKey('product_filter_chip');
  static const productStatusBadge = TestKey('product_status_badge');

  // 5-Step Claim Filing Wizard
  static const wizardProductSelector = TestKey('wizard_product_selector');
  static const wizardClaimTypeRadio = TestKey('wizard_claim_type_radio');
  static const wizardIssueTitleInput = TestKey('wizard_issue_title_input');
  static const wizardIssueDescriptionInput = TestKey('wizard_issue_desc_input');
  static const wizardIncidentDateInput = TestKey('wizard_incident_date_input');
  static const wizardUploadAttachmentBtn = TestKey('wizard_upload_attachment_btn');
  static const wizardNextBtn = TestKey('wizard_next_btn');
  static const wizardBackBtn = TestKey('wizard_back_btn');
  static const wizardSubmitBtn = TestKey('wizard_submit_btn');
  static const wizardCancelBtn = TestKey('wizard_cancel_btn');

  // Claim Detail & Timeline
  static const claimTimelineStep = TestKey('claim_timeline_step');
  static const claimStatusBadge = TestKey('claim_status_badge');
  static const claimPriorityScore = TestKey('claim_priority_score');
  static const claimResolutionNotes = TestKey('claim_resolution_notes');
  static const claimPdfExportBtn = TestKey('claim_pdf_export_btn');
  static const claimTabAll = TestKey('claim_tab_all');
  static const claimTabPending = TestKey('claim_tab_pending');
  static const claimTabApproved = TestKey('claim_tab_approved');
  static const claimTabRejected = TestKey('claim_tab_rejected');

  // Notifications
  static const notificationItem = TestKey('notification_item');
  static const notificationMarkAllReadBtn = TestKey('notification_mark_all_read_btn');
  static const notificationEmptyState = TestKey('notification_empty_state');

  // Profile & Settings
  static const themeToggleBtn = TestKey('theme_toggle_btn');
  static const profileEditBtn = TestKey('profile_edit_btn');
  static const profilePhoneInput = TestKey('profile_phone_input');
  static const profileSaveBtn = TestKey('profile_save_btn');

  // Admin Controls
  static const adminClaimSearchInput = TestKey('admin_claim_search_input');
  static const adminClaimStatusDropdown = TestKey('admin_claim_status_dropdown');
  static const adminNotesInput = TestKey('admin_notes_input');
  static const adminResolutionInput = TestKey('admin_resolution_input');
  static const adminPriorityOverrideInput = TestKey('admin_priority_override_input');
  static const adminUpdateStatusBtn = TestKey('admin_update_status_btn');
  static const adminAnalyticsChart = TestKey('admin_analytics_chart');
  static const adminKpiTotalClaims = TestKey('admin_kpi_total_claims');
  static const adminKpiActiveClaims = TestKey('admin_kpi_active_claims');
  static const adminKpiApprovalRate = TestKey('admin_kpi_approval_rate');
  static const adminKpiAvgResolution = TestKey('admin_kpi_avg_resolution');
  static const adminUserDirectory = TestKey('admin_user_directory');
}
