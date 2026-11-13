/// Deterministic personas and test data fixtures for Claimly E2E tests.
import 'dart:math';

class TestPersona {
  final String id;
  final String email;
  final String password;
  final String fullName;
  final String role;
  final String phone;

  const TestPersona({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.phone = '+1-555-0199',
  });
}

class TestProductFixture {
  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final String serialNumber;
  final String purchaseDate;
  final int warrantyMonths;
  final String expectedExpiryDate;
  final String retailer;

  const TestProductFixture({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.purchaseDate,
    required this.warrantyMonths,
    required this.expectedExpiryDate,
    this.retailer = 'Best Buy',
  });

  Map<String, dynamic> toJson(String userId) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category,
    'brand': brand,
    'model': model,
    'serial_number': serialNumber,
    'purchase_date': purchaseDate,
    'warranty_period_months': warrantyMonths,
    'warranty_expiry_date': expectedExpiryDate,
    'retailer': retailer,
  };
}

class TestClaimFixture {
  final String id;
  final String productId;
  final String claimType;
  final String title;
  final String description;
  final String incidentDate;
  final String status;
  final int priority;

  const TestClaimFixture({
    required this.id,
    required this.productId,
    required this.claimType,
    required this.title,
    required this.description,
    required this.incidentDate,
    this.status = 'submitted',
    this.priority = 50,
  });

  Map<String, dynamic> toJson(String userId) => {
    'id': id,
    'user_id': userId,
    'product_id': productId,
    'type': claimType,
    'title': title,
    'description': description,
    'incident_date': incidentDate,
    'status': status,
    'priority': priority,
  };
}

class TestDataSeeder {
  // Deterministic Personas
  static const customerSarah = TestPersona(
    id: '11111111-1111-4111-8111-111111111111',
    email: 'sarah.jenkins@claimly.com',
    password: 'SecureP@ss2026!',
    fullName: 'Sarah Jenkins',
    role: 'customer',
    phone: '+1-555-0144',
  );

  static const adminMarcus = TestPersona(
    id: '22222222-2222-4222-8222-222222222222',
    email: 'marcus.admin@claimly.com',
    password: 'AdminSecret2026!',
    fullName: 'Marcus Vance',
    role: 'admin',
    phone: '+1-555-0800',
  );

  static const customerJohn = TestPersona(
    id: '33333333-3333-4333-8333-333333333333',
    email: 'john.customer@claimly.com',
    password: 'CustomerPass123!',
    fullName: 'John Doe',
    role: 'customer',
    phone: '+1-555-0188',
  );

  // Deterministic Product Fixtures
  static const productActiveLaptop = TestProductFixture(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    name: 'Apple MacBook Pro 16"',
    category: 'Electronics',
    brand: 'Apple',
    model: 'M3 Max',
    serialNumber: 'C02XYZ1234',
    purchaseDate: '2026-03-01',
    warrantyMonths: 36,
    expectedExpiryDate: '2029-03-01',
  );

  static const productExpiringSoonMonitor = TestProductFixture(
    id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    name: 'Dell UltraSharp 27" Monitor',
    category: 'Electronics',
    brand: 'Dell',
    model: 'U2723QE',
    serialNumber: 'CN-827391-A',
    purchaseDate: '2025-11-25',
    warrantyMonths: 12,
    expectedExpiryDate: '2026-11-25',
  );

  static const productExpiredVacuum = TestProductFixture(
    id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    name: 'Dyson V15 Detect Vacuum',
    category: 'Home Appliances',
    brand: 'Dyson',
    model: 'V15',
    serialNumber: 'DY-9812-V15',
    purchaseDate: '2024-10-01',
    warrantyMonths: 24,
    expectedExpiryDate: '2026-10-01',
  );

  static const productGracePeriodHeadphones = TestProductFixture(
    id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    name: 'Sony WH-1000XM5 Headphones',
    category: 'Electronics',
    brand: 'Sony',
    model: 'WH-1000XM5',
    serialNumber: 'SN-WH-9921',
    purchaseDate: '2025-11-06',
    warrantyMonths: 12,
    expectedExpiryDate: '2026-11-06',
  );

  // Helper generators for isolation & uniqueness
  static final _random = Random();

  static String generateUniqueEmail([String prefix = 'test']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randSuffix = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_${timestamp}_$randSuffix@claimly.com';
  }

  static String generateUuid() {
    String s4() => _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    final y = (8 + _random.nextInt(4)).toRadixString(16); // 8, 9, a, or b
    final y3 = _random.nextInt(0x1000).toRadixString(16).padLeft(3, '0');
    final v3 = _random.nextInt(0x1000).toRadixString(16).padLeft(3, '0');
    return '${s4()}${s4()}-${s4()}-4$v3-$y$y3-${s4()}${s4()}${s4()}';
  }

  static String formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
           '${dt.month.toString().padLeft(2, '0')}-'
           '${dt.day.toString().padLeft(2, '0')}';
  }

  static DateTime calculateExpiryDate(DateTime purchaseDate, int months) {
    var year = purchaseDate.year;
    var month = purchaseDate.month + months;
    while (month > 12) {
      year += 1;
      month -= 12;
    }
    // Handle days overflow for end of month (e.g. Feb 28/29, April 30)
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final day = purchaseDate.day > daysInMonth ? daysInMonth : purchaseDate.day;
    return DateTime(year, month, day);
  }
}
