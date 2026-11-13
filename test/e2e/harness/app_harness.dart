/// Application-level opaque test harness orchestrating UI Driver, Backend Harness, and test fixtures.
import 'backend_harness.dart';
import 'ui_driver.dart';
import 'test_data_seeder.dart';
import 'assertions.dart';

class AppHarness {
  final BackendHarness backend;
  final UIDriver ui;
  final List<String> createdUserIds = [];
  final List<String> createdProductIds = [];
  final List<String> createdClaimIds = [];
  String? currentAuthToken;
  TestPersona? currentPersona;

  AppHarness({
    required this.backend,
    required this.ui,
  });

  factory AppHarness.create() {
    final backend = BackendHarness.fromEnv();
    final ui = UIDriver();
    return AppHarness(backend: backend, ui: ui);
  }

  Future<void> setUp() async {
    // Reset driver state
    ui.currentRoute = '/splash';
    ui.currentTheme = 'light';
  }

  Future<void> tearDown() async {
    // Clean up created resources in reverse relational order
    for (final claimId in createdClaimIds) {
      await backend.deleteRow('claims', 'id=eq.$claimId', useServiceRole: true);
    }
    for (final productId in createdProductIds) {
      await backend.deleteRow('products', 'id=eq.$productId', useServiceRole: true);
    }
    for (final userId in createdUserIds) {
      await backend.deleteAuthUser(userId);
    }
    createdClaimIds.clear();
    createdProductIds.clear();
    createdUserIds.clear();
    backend.close();
  }

  Future<void> authenticateAs(TestPersona persona) async {
    final res = await backend.signIn(
      email: persona.email,
      password: persona.password,
    );
    if (res.isSuccess && res.json != null) {
      final data = res.json as Map<String, dynamic>;
      currentAuthToken = data['access_token'] as String?;
      currentPersona = persona;
    } else {
      // If persona does not exist yet in Auth, create it
      final signupRes = await backend.signUp(
        email: persona.email,
        password: persona.password,
        data: {'full_name': persona.fullName, 'role': persona.role},
      );
      if (signupRes.isSuccess && signupRes.json != null) {
        final data = signupRes.json as Map<String, dynamic>;
        currentAuthToken = data['access_token'] as String?;
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null && user['id'] != null) {
          createdUserIds.add(user['id'] as String);
        }
        currentPersona = persona;
      }
    }
  }

  Future<void> ensureUserRegistered(TestPersona persona) async {
    final res = await backend.createAdminUser(
      email: persona.email,
      password: persona.password,
      metadata: {'full_name': persona.fullName, 'role': persona.role},
      emailConfirm: true,
    );
    if (res.isSuccess && res.json != null) {
      final data = res.json as Map<String, dynamic>;
      final id = data['id'] as String?;
      if (id != null) {
        createdUserIds.add(id);
      }
    }
  }

  void trackCreatedProduct(String id) => createdProductIds.add(id);
  void trackCreatedClaim(String id) => createdClaimIds.add(id);

  void assertUserRole(String expectedRole) {
    Assertions.notNull(currentPersona, 'No persona currently authenticated');
    Assertions.equal(
      currentPersona!.role,
      expectedRole,
      'Authenticated persona role mismatch',
    );
  }
}
