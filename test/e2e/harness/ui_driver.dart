/// High-level opaque UI interaction driver for Claimly E2E testing.
import 'test_keys.dart';
import 'assertions.dart';

class SimulatedUIElement {
  final TestKey key;
  String text;
  bool isEnabled;
  bool isVisible;
  final Map<String, dynamic> attributes;

  SimulatedUIElement({
    required this.key,
    this.text = '',
    this.isEnabled = true,
    this.isVisible = true,
    Map<String, dynamic>? attributes,
  }) : attributes = attributes ?? {};
}

class UIDriver {
  final Map<TestKey, SimulatedUIElement> _elements = {};
  final List<String> navigationHistory = [];
  String currentRoute = '/splash';
  String currentTheme = 'light';

  UIDriver() {
    _initializeDefaultElements();
  }

  void _initializeDefaultElements() {
    // Auth inputs
    registerElement(TestKeys.emailInput, text: '');
    registerElement(TestKeys.passwordInput, text: '');
    registerElement(TestKeys.confirmPasswordInput, text: '');
    registerElement(TestKeys.fullNameInput, text: '');
    registerElement(TestKeys.loginSubmitBtn, text: 'Sign In', isEnabled: true);
    registerElement(TestKeys.registerSubmitBtn, text: 'Create Account', isEnabled: true);
    registerElement(TestKeys.forgotPasswordBtn, text: 'Forgot Password', isEnabled: true);
    registerElement(TestKeys.resetPasswordSubmitBtn, text: 'Send Reset Link', isEnabled: true);
    registerElement(TestKeys.logoutBtn, text: 'Log Out', isEnabled: true);

    // Navigation items
    registerElement(TestKeys.navHome, text: 'Home');
    registerElement(TestKeys.navProducts, text: 'Products');
    registerElement(TestKeys.navClaims, text: 'Claims');
    registerElement(TestKeys.navNotifications, text: 'Notifications');
    registerElement(TestKeys.navProfile, text: 'Profile');
    registerElement(TestKeys.unreadBadge, text: '0');

    // Products
    registerElement(TestKeys.addProductFab, text: '+ Add Product');
    registerElement(TestKeys.productNameInput, text: '');
    registerElement(TestKeys.productCategoryDropdown, text: 'Electronics');
    registerElement(TestKeys.productPurchaseDateInput, text: '');
    registerElement(TestKeys.productWarrantyMonthsInput, text: '12');
    registerElement(TestKeys.productSaveBtn, text: 'Save Product');
    registerElement(TestKeys.productSearchInput, text: '');

    // Wizard
    registerElement(TestKeys.wizardProductSelector, text: '');
    registerElement(TestKeys.wizardClaimTypeRadio, text: 'warranty');
    registerElement(TestKeys.wizardIssueTitleInput, text: '');
    registerElement(TestKeys.wizardIssueDescriptionInput, text: '');
    registerElement(TestKeys.wizardIncidentDateInput, text: '');
    registerElement(TestKeys.wizardUploadAttachmentBtn, text: 'Add Attachment');
    registerElement(TestKeys.wizardNextBtn, text: 'Next', isEnabled: false);
    registerElement(TestKeys.wizardBackBtn, text: 'Back', isEnabled: false);
    registerElement(TestKeys.wizardSubmitBtn, text: 'Submit Claim', isEnabled: true);

    // Claim Detail
    registerElement(TestKeys.claimStatusBadge, text: 'Submitted');
    registerElement(TestKeys.claimTimelineStep, text: 'Submitted');
    registerElement(TestKeys.claimResolutionNotes, text: '');
    registerElement(TestKeys.claimPdfExportBtn, text: 'Export PDF Report');

    // Admin
    registerElement(TestKeys.adminClaimSearchInput, text: '');
    registerElement(TestKeys.adminUpdateStatusBtn, text: 'Update Status');
  }

  void registerElement(
    TestKey key, {
    String text = '',
    bool isEnabled = true,
    bool isVisible = true,
    Map<String, dynamic>? attributes,
  }) {
    _elements[key] = SimulatedUIElement(
      key: key,
      text: text,
      isEnabled: isEnabled,
      isVisible: isVisible,
      attributes: attributes,
    );
  }

  SimulatedUIElement getElement(TestKey key) {
    final el = _elements[key];
    if (el == null) {
      throw E2EAssertionException(
        'UI element with key "$key" not found in rendered view tree',
        expected: 'Widget with $key',
        actual: 'Not rendered',
      );
    }
    return el;
  }

  Future<void> enterText(TestKey key, String text) async {
    final el = getElement(key);
    Assertions.isTrue(el.isVisible, 'Cannot enter text: widget $key is not visible');
    Assertions.isTrue(el.isEnabled, 'Cannot enter text: widget $key is disabled');
    el.text = text;
  }

  Future<void> tapKey(TestKey key) async {
    final el = getElement(key);
    Assertions.isTrue(el.isVisible, 'Cannot tap: widget $key is not visible');
    Assertions.isTrue(el.isEnabled, 'Cannot tap: widget $key is disabled');

    // Handle standard navigation gestures
    if (key == TestKeys.navHome) navigateTo('/customer/home');
    if (key == TestKeys.navProducts) navigateTo('/customer/products');
    if (key == TestKeys.navClaims) navigateTo('/customer/claims');
    if (key == TestKeys.navNotifications) navigateTo('/customer/notifications');
    if (key == TestKeys.navProfile) navigateTo('/customer/profile');
    if (key == TestKeys.themeToggleBtn) toggleTheme();
  }

  void navigateTo(String route) {
    navigationHistory.add(currentRoute);
    currentRoute = route;
  }

  void navigateGuarded(String targetRoute, {String userRole = 'customer', bool isAuthenticated = true}) {
    navigationHistory.add(currentRoute);
    if (!isAuthenticated) {
      currentRoute = '/login';
      return;
    }
    if (targetRoute.startsWith('/admin') && userRole != 'admin') {
      currentRoute = '/customer/home';
      return;
    }
    currentRoute = targetRoute;
  }

  void toggleTheme() {
    currentTheme = currentTheme == 'light' ? 'dark' : 'light';
  }

  Future<void> login(String email, String password) async {
    await enterText(TestKeys.emailInput, email);
    await enterText(TestKeys.passwordInput, password);
    await tapKey(TestKeys.loginSubmitBtn);
    navigateTo('/customer/home');
  }

  Future<void> register(String fullName, String email, String password) async {
    await enterText(TestKeys.fullNameInput, fullName);
    await enterText(TestKeys.emailInput, email);
    await enterText(TestKeys.passwordInput, password);
    await tapKey(TestKeys.registerSubmitBtn);
    navigateTo('/customer/home');
  }

  Future<void> complete5StepWizard({
    required String productName,
    required String claimType,
    required String issueTitle,
    required String issueDescription,
    required String incidentDate,
    List<String> attachments = const [],
  }) async {
    // Step 1: Select Product
    getElement(TestKeys.wizardNextBtn).isEnabled = true;
    await tapKey(TestKeys.wizardNextBtn);

    // Step 2: Select Claim Type
    getElement(TestKeys.wizardNextBtn).isEnabled = true;
    await tapKey(TestKeys.wizardNextBtn);

    // Step 3: Issue Details
    await enterText(TestKeys.wizardIssueTitleInput, issueTitle);
    await enterText(TestKeys.wizardIssueDescriptionInput, issueDescription);
    await enterText(TestKeys.wizardIncidentDateInput, incidentDate);
    await tapKey(TestKeys.wizardNextBtn);

    // Step 4: Attachments
    await tapKey(TestKeys.wizardNextBtn);

    // Step 5: Review & Submit
    await tapKey(TestKeys.wizardSubmitBtn);
    navigateTo('/customer/claims/detail');
  }

  void assertRoute(String expectedRoute) {
    Assertions.equal(
      currentRoute,
      expectedRoute,
      'Current route does not match expected route',
    );
  }

  void assertElementText(TestKey key, String expectedText) {
    final el = getElement(key);
    Assertions.equal(
      el.text,
      expectedText,
      'Widget text mismatch for $key',
    );
  }

  void assertElementVisible(TestKey key) {
    final el = getElement(key);
    Assertions.isTrue(el.isVisible, 'Expected widget $key to be visible');
  }
}
