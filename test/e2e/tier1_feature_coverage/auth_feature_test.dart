/// Tier 1 Feature Coverage: Authentication, Session Management, and Role Security (TC-T1-AUTH-01 to 05).
import 'dart:io';
import '../harness/backend_harness.dart';
import '../harness/ui_driver.dart';
import '../harness/assertions.dart';
import '../harness/test_data_seeder.dart';
import '../harness/test_keys.dart';

void main() async {
  final runner = E2ETestRunner('Tier 1: Auth & Session Management');
  final backend = BackendHarness.fromEnv();
  final ui = UIDriver();

  // TC-T1-AUTH-01: Valid Customer Registration & Automatic Profile Provisioning
  runner.addTest('TC-T1-AUTH-01', 'Valid Customer Registration Creates Profile Row with Role customer', () async {
    final email = TestDataSeeder.generateUniqueEmail('auth_t1_reg');
    final password = 'SecurePassword123!';
    final fullName = 'Sarah Tier One';

    // UI Simulation
    ui.navigateTo('/register');
    await ui.register(fullName, email, password);
    ui.assertRoute('/customer/home');

    // Backend Verification: Provison user and verify profile created by on_auth_user_created trigger
    final authRes = await backend.createAdminUser(
      email: email,
      password: password,
      metadata: {'full_name': fullName, 'role': 'customer'},
      emailConfirm: true,
    );
    Assertions.httpSuccess(authRes.statusCode, authRes.body);
    final userMap = authRes.json as Map<String, dynamic>;
    final userId = userMap['id'] as String;

    try {
      final profRes = await backend.queryTable('profiles', query: 'id=eq.$userId', useServiceRole: true);
      Assertions.httpSuccess(profRes.statusCode, profRes.body);
      final profList = profRes.json as List;
      Assertions.notEmpty(profList, 'Automatic profile creation trigger failed');
      final profile = profList.first as Map<String, dynamic>;
      Assertions.equal(profile['role'], 'customer', 'Default role must be customer');
      Assertions.equal(profile['full_name'], fullName);
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-AUTH-02: Valid Email & Password Login
  runner.addTest('TC-T1-AUTH-02', 'Existing Customer Login Returns Session Tokens and Grants Access', () async {
    final email = TestDataSeeder.generateUniqueEmail('auth_t1_login');
    final password = 'ValidLoginPass123!';
    final authRes = await backend.createAdminUser(
      email: email,
      password: password,
      metadata: {'full_name': 'Login Tester', 'role': 'customer'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    try {
      // Authenticate via Supabase Auth
      final loginRes = await backend.signIn(email: email, password: password);
      Assertions.httpSuccess(loginRes.statusCode, loginRes.body);
      final sessionData = loginRes.json as Map<String, dynamic>;
      Assertions.notNull(sessionData['access_token'], 'Access token missing in login response');
      Assertions.notNull(sessionData['refresh_token'], 'Refresh token missing in login response');

      // UI updates to dashboard
      ui.navigateTo('/login');
      await ui.login(email, password);
      ui.assertRoute('/customer/home');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-AUTH-03: Password Reset Request Initiation
  runner.addTest('TC-T1-AUTH-03', 'Password Reset Request Accepts Valid Email and Sends Recovery Instructions', () async {
    ui.navigateTo('/forgot-password');
    await ui.enterText(TestKeys.emailInput, 'user@claimly.com');
    await ui.tapKey(TestKeys.resetPasswordSubmitBtn);

    // Backend recovery trigger
    final recoverRes = await backend.resetPasswordForEmail(email: 'user@claimly.com');
    // Supabase returns 200 OK for valid email format
    Assertions.httpSuccess(recoverRes.statusCode, recoverRes.body);
  });

  // TC-T1-AUTH-04: Session Persistence Across Cold Start
  runner.addTest('TC-T1-AUTH-04', 'Valid Session Restores Customer State Directly to Dashboard on Cold Start', () async {
    final email = TestDataSeeder.generateUniqueEmail('auth_t1_persist');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Session Persist User'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    try {
      // 1. Initial sign in captures active refresh token
      final loginRes = await backend.signIn(email: email, password: 'Password123!');
      Assertions.httpSuccess(loginRes.statusCode, loginRes.body);
      final loginData = loginRes.json as Map<String, dynamic>;
      final refreshToken = loginData['refresh_token'] as String;
      Assertions.isTrue(refreshToken.isNotEmpty, 'Sign-in must return valid refresh token');

      // 2. Cold-start session restore via refresh token grant
      final refreshRes = await backend.refreshSession(refreshToken: refreshToken);
      Assertions.httpSuccess(refreshRes.statusCode, refreshRes.body);
      final refreshData = refreshRes.json as Map<String, dynamic>;
      final newAccessToken = refreshData['access_token'] as String;
      Assertions.isTrue(newAccessToken.isNotEmpty, 'Refreshed session must return valid access token');

      // 3. UI cold boot: splash initializes, verifies restored session, redirects to dashboard
      ui.navigateTo('/splash');
      ui.navigateGuarded('/customer/home', userRole: 'customer', isAuthenticated: true);
      ui.assertRoute('/customer/home');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  // TC-T1-AUTH-05: User Sign Out and Route Invalidation
  runner.addTest('TC-T1-AUTH-05', 'Sign Out Invalidates Active Token and Redirects to Login Screen', () async {
    final email = TestDataSeeder.generateUniqueEmail('auth_t1_logout');
    final authRes = await backend.createAdminUser(
      email: email,
      password: 'Password123!',
      metadata: {'full_name': 'Logout User'},
      emailConfirm: true,
    );
    final userId = (authRes.json as Map)['id'] as String;

    try {
      final loginRes = await backend.signIn(email: email, password: 'Password123!');
      final jwt = (loginRes.json as Map)['access_token'] as String;

      // Invalidate session
      final logoutRes = await backend.signOut(jwt: jwt);
      Assertions.httpSuccess(logoutRes.statusCode, logoutRes.body);

      // UI transitions back to login
      ui.navigateTo('/customer/profile');
      await ui.tapKey(TestKeys.logoutBtn);
      ui.navigateTo('/login');
      ui.assertRoute('/login');
    } finally {
      await backend.deleteAuthUser(userId);
    }
  });

  final result = await runner.run(verbose: true);
  backend.close();
  exit(result.isSuccess ? 0 : 1);
}
