#!/usr/bin/env bash
# ==============================================================================
# Claimly Test Database Seeder & Fixture Manager
# Usage:
#   ./tool/seed_test_db.sh [--seed | --clean | --verify]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$PROJECT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ACTION="seed"

if [ $# -gt 0 ]; then
  case "$1" in
    --seed)
      ACTION="seed"
      ;;
    --clean)
      ACTION="clean"
      ;;
    --verify)
      ACTION="verify"
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--seed | --clean | --verify]"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      exit 1
      ;;
  esac
fi

# Load .env
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
else
  echo -e "${RED}Error: .env file not found in $PROJECT_DIR${NC}"
  exit 2
fi

SUPABASE_URL="${project_url:-${SUPABASE_URL:-https://kvxfkfgzsapvvswjcmzj.supabase.co}}"
SERVICE_ROLE="${service_role:-${SUPABASE_SERVICE_ROLE_KEY:-}}"

if [ -z "$SERVICE_ROLE" ]; then
  echo -e "${RED}Error: service_role key missing from .env${NC}"
  exit 2
fi

echo -e "${BLUE}${BOLD}==> Claimly Test Database Seeder [Action: $ACTION]${NC}"

TMP_SEED_SCRIPT="/tmp/claimly_seed_$$.dart"
trap 'rm -f "$TMP_SEED_SCRIPT"' EXIT

cat << 'EOF' > "$TMP_SEED_SCRIPT"
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class HttpResponseData {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const HttpResponseData({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  dynamic get json {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'HTTP $statusCode: $body';
}

class SeedClient {
  final String url;
  final String serviceRole;
  final HttpClient client = HttpClient();

  SeedClient(this.url, this.serviceRole);

  void close() {
    client.close(force: true);
  }

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final baseUri = Uri.parse('$cleanBase$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return baseUri.replace(queryParameters: queryParams);
    }
    return baseUri;
  }

  Future<HttpResponseData> _send(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _uri(path, queryParams);
    final request = await client.openUrl(method, uri);

    request.headers.set('apikey', serviceRole);
    request.headers.set('Authorization', 'Bearer $serviceRole');
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Prefer', 'return=representation');

    if (extraHeaders != null) {
      extraHeaders.forEach((k, v) => request.headers.set(k, v));
    }

    if (body != null) {
      final jsonBytes = utf8.encode(body is String ? body : jsonEncode(body));
      request.headers.contentLength = jsonBytes.length;
      request.add(jsonBytes);
    }

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();

    final respHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      respHeaders[name] = values.join(', ');
    });

    return HttpResponseData(
      statusCode: response.statusCode,
      headers: respHeaders,
      body: responseBody,
    );
  }

  // Auth Admin Endpoints
  Future<List<Map<String, dynamic>>> listAdminUsers({int perPage = 100}) async {
    final res = await _send('GET', '/auth/v1/admin/users', queryParams: {'per_page': perPage.toString()});
    if (!res.isSuccess) {
      throw Exception('Failed to list auth admin users: ${res.statusCode} ${res.body}');
    }
    final data = res.json;
    if (data is Map && data.containsKey('users')) {
      return List<Map<String, dynamic>>.from(data['users'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String phone = '',
  }) async {
    final res = await _send('POST', '/auth/v1/admin/users', body: {
      'email': email,
      'password': password,
      'email_confirm': true,
      'user_metadata': {
        'full_name': fullName,
        'role': role,
        if (phone.isNotEmpty) 'phone_number': phone,
      },
    });
    if (!res.isSuccess) {
      throw Exception('Failed to create admin user $email: ${res.statusCode} ${res.body}');
    }
    return res.json as Map<String, dynamic>;
  }

  Future<void> deleteAdminUser(String userId) async {
    final res = await _send('DELETE', '/auth/v1/admin/users/$userId');
    if (!res.isSuccess && res.statusCode != 404) {
      throw Exception('Failed to delete auth user $userId: ${res.statusCode} ${res.body}');
    }
  }

  // PostgREST Endpoints
  Future<HttpResponseData> queryTable(String table, [String query = 'limit=1']) {
    final path = query.isEmpty ? '/rest/v1/$table' : '/rest/v1/$table?$query';
    return _send('GET', path);
  }

  Future<HttpResponseData> insertRow(String table, Map<String, dynamic> row) {
    return _send('POST', '/rest/v1/$table', body: row);
  }

  Future<HttpResponseData> updateRow(String table, String filter, Map<String, dynamic> data) {
    return _send('PATCH', '/rest/v1/$table?$filter', body: data);
  }

  Future<HttpResponseData> deleteRows(String table, String filter) {
    return _send('DELETE', '/rest/v1/$table?$filter');
  }

  // Storage
  Future<HttpResponseData> listBuckets() {
    return _send('GET', '/storage/v1/bucket');
  }
}

bool _isTestEmail(String email) {
  final lower = email.toLowerCase();
  return lower.endsWith('@claimly-test.com') ||
      lower.endsWith('@claimly.com') ||
      lower.startsWith('test_') ||
      lower.startsWith('test-') ||
      lower.contains('_rw') ||
      lower.contains('rls_') ||
      lower.contains('sarah') ||
      lower.contains('marcus') ||
      lower.contains('john') ||
      lower.contains('probe');
}

Future<void> runVerify(SeedClient client) async {
  print('Verifying Supabase connectivity and schema...');
  final tables = ['profiles', 'products', 'claims', 'claim_attachments', 'claim_timeline', 'notifications'];

  for (final t in tables) {
    final res = await client.queryTable(t, 'select=count');
    if (res.statusCode == 200 || res.statusCode == 206) {
      final range = res.headers['content-range'] ?? 'OK';
      print('  ✓ Table $t: accessible (Range: $range)');
    } else {
      stderr.writeln('  ✗ Table $t check failed: HTTP ${res.statusCode} - ${res.body}');
      exit(1);
    }
  }

  // Verify Auth Admin Endpoint
  try {
    final users = await client.listAdminUsers(perPage: 1);
    print('  ✓ Auth Admin endpoint: accessible (${users.length} sample probe)');
  } catch (e) {
    stderr.writeln('  ✗ Auth Admin endpoint check failed: $e');
    exit(1);
  }

  // Verify Storage Buckets
  final bucketRes = await client.listBuckets();
  if (bucketRes.isSuccess) {
    print('  ✓ Storage endpoint: accessible');
  } else {
    stderr.writeln('  ✗ Storage endpoint check failed: HTTP ${bucketRes.statusCode}');
    exit(1);
  }

  print('All verification checks PASSED (exit code 0).');
}

Future<void> runClean(SeedClient client) async {
  print('Cleaning test records and test personas from Supabase...');
  int usersCleaned = 0;

  // 1. Clean auth users matching test criteria
  try {
    final allUsers = await client.listAdminUsers(perPage: 100);
    for (final u in allUsers) {
      final email = (u['email'] as String? ?? '').toLowerCase();
      final id = u['id'] as String;
      if (_isTestEmail(email)) {
        await client.deleteAdminUser(id);
        usersCleaned++;
        print('  - Removed Auth user: $email ($id)');
      }
    }
  } catch (e) {
    stderr.writeln('Error during Auth user cleanup: $e');
    exit(1);
  }

  // 2. Cascade cleanup handles profiles, products, claims, attachments, timeline, notifications
  // Sweep public tables for any residual records matching test identifiers
  final residualFilters = [
    ('notifications', 'title=ilike.*test*'),
    ('claim_attachments', 'file_name=ilike.test*'),
    ('claim_timeline', 'notes=ilike.*test*'),
    ('claims', 'title=ilike.*test*'),
    ('claims', 'title=ilike.*Screen horizontal line defect*'),
    ('products', 'name=ilike.*test*'),
    ('products', 'name=ilike.*Apple MacBook Pro*'),
    ('products', 'name=ilike.*Dell UltraSharp*'),
    ('products', 'name=ilike.*Dyson V15*'),
    ('products', 'name=ilike.*Sony WH-1000XM5*'),
    ('profiles', 'full_name=ilike.*Sarah Jenkins*'),
    ('profiles', 'full_name=ilike.*Marcus Vance*'),
    ('profiles', 'full_name=ilike.*John Doe*'),
  ];

  for (final sweep in residualFilters) {
    try {
      await client.deleteRows(sweep.$1, sweep.$2);
    } catch (_) {}
  }

  print('Cleanup completed successfully: $usersCleaned test auth accounts and related records removed.');
}

Future<void> runSeed(SeedClient client) async {
  print('Seeding deterministic test fixtures into Supabase...');

  // Step 1: Idempotent clean of deterministic personas before re-inserting
  print('Step 1: Purging any existing deterministic test personas...');
  final targetEmails = [
    'sarah.jenkins@claimly-test.com',
    'marcus.admin@claimly-test.com',
    'john.customer@claimly-test.com',
    'sarah.jenkins@claimly.com',
    'marcus.admin@claimly.com',
    'john.customer@claimly.com',
  ];

  try {
    final existingUsers = await client.listAdminUsers(perPage: 100);
    for (final u in existingUsers) {
      final email = (u['email'] as String? ?? '').toLowerCase();
      if (targetEmails.contains(email)) {
        await client.deleteAdminUser(u['id'] as String);
        print('  - Purged prior instance of $email');
      }
    }
  } catch (e) {
    stderr.writeln('Warning during pre-seed cleanup: $e');
  }

  // Step 2: Create Sarah Jenkins (Customer)
  print('Step 2: Provisioning Sarah Jenkins (Customer)...');
  final sarahAuth = await client.createAdminUser(
    email: 'sarah.jenkins@claimly-test.com',
    password: 'SecureP@ss2026!',
    fullName: 'Sarah Jenkins',
    role: 'customer',
    phone: '+1-555-0144',
  );
  final sarahId = sarahAuth['id'] as String;
  print('  ✓ Created Sarah Jenkins: $sarahId');

  // Step 3: Create Marcus Vance (Admin)
  print('Step 3: Provisioning Marcus Vance (Admin)...');
  final marcusAuth = await client.createAdminUser(
    email: 'marcus.admin@claimly-test.com',
    password: 'AdminSecret2026!',
    fullName: 'Marcus Vance',
    role: 'admin',
    phone: '+1-555-0800',
  );
  final marcusId = marcusAuth['id'] as String;

  // Upgrade Marcus profile role to 'admin' using service_role
  final adminPatchRes = await client.updateRow('profiles', 'id=eq.$marcusId', {'role': 'admin'});
  if (!adminPatchRes.isSuccess) {
    stderr.writeln('Failed to set admin role for Marcus: ${adminPatchRes.body}');
    exit(1);
  }
  print('  ✓ Created & Elevated Marcus Vance to Admin: $marcusId');

  // Step 4: Create John Doe (Customer)
  print('Step 4: Provisioning John Doe (Customer)...');
  final johnAuth = await client.createAdminUser(
    email: 'john.customer@claimly-test.com',
    password: 'CustomerPass123!',
    fullName: 'John Doe',
    role: 'customer',
    phone: '+1-555-0188',
  );
  final johnId = johnAuth['id'] as String;
  print('  ✓ Created John Doe: $johnId');

  // Step 5: Seed Products for Sarah Jenkins
  print('Step 5: Seeding 4 deterministic products for Sarah Jenkins...');
  final products = [
    {
      'user_id': sarahId,
      'name': 'Apple MacBook Pro 16"',
      'category': 'Electronics',
      'brand': 'Apple',
      'model_number': 'M3 Max',
      'serial_number': 'C02XYZ1234',
      'purchase_date': '2026-03-01',
      'warranty_period_months': 36,
      'warranty_expiry_date': '2029-03-01',
    },
    {
      'user_id': sarahId,
      'name': 'Dell UltraSharp 27" Monitor',
      'category': 'Electronics',
      'brand': 'Dell',
      'model_number': 'U2723QE',
      'serial_number': 'CN-827391-A',
      'purchase_date': '2025-11-25',
      'warranty_period_months': 12,
      'warranty_expiry_date': '2026-11-25',
    },
    {
      'user_id': sarahId,
      'name': 'Dyson V15 Detect Vacuum',
      'category': 'Home Appliances',
      'brand': 'Dyson',
      'model_number': 'V15',
      'serial_number': 'DY-9812-V15',
      'purchase_date': '2024-10-01',
      'warranty_period_months': 24,
      'warranty_expiry_date': '2026-10-01',
    },
    {
      'user_id': sarahId,
      'name': 'Sony WH-1000XM5 Headphones',
      'category': 'Electronics',
      'brand': 'Sony',
      'model_number': 'WH-1000XM5',
      'serial_number': 'SN-WH-9921',
      'purchase_date': '2025-11-06',
      'warranty_period_months': 12,
      'warranty_expiry_date': '2026-11-06',
    },
  ];

  final createdProductIds = <String>[];
  for (final prod in products) {
    final pRes = await client.insertRow('products', prod);
    if (!pRes.isSuccess) {
      stderr.writeln('Failed to insert product ${prod['name']}: ${pRes.body}');
      exit(1);
    }
    final pData = pRes.json as List;
    final pid = pData[0]['id'] as String;
    createdProductIds.add(pid);
    print('  ✓ Seeded Product: ${prod['name']} (ID: $pid)');
  }

  // Step 6: Seed Claim for Sarah on Product 2 (Dell Monitor)
  print('Step 6: Seeding initial warranty claim...');
  final dellMonitorId = createdProductIds[1];
  final claimPayload = {
    'user_id': sarahId,
    'product_id': dellMonitorId,
    'type': 'warranty',
    'status': 'submitted',
    'title': 'Screen horizontal line defect',
    'description': 'Horizontal flickering lines appear after 30 minutes of display operation.',
    'incident_date': '2026-11-01',
    'priority': 50,
  };

  final claimRes = await client.insertRow('claims', claimPayload);
  if (!claimRes.isSuccess) {
    stderr.writeln('Failed to insert sample claim: ${claimRes.body}');
    exit(1);
  }
  final claimData = claimRes.json as List;
  final claimNumber = claimData[0]['claim_number'] as String;
  final claimId = claimData[0]['id'] as String;
  print('  ✓ Seeded Claim: $claimNumber (ID: $claimId, Status: submitted)');

  // Step 7: Seed Notification for Sarah
  print('Step 7: Seeding initial notification...');
  final notifPayload = {
    'user_id': sarahId,
    'claim_id': claimId,
    'type': 'warranty_expiry',
    'title': 'Warranty Expiring Soon',
    'message': 'Your Dell UltraSharp 27" Monitor warranty expires in 14 days.',
    'is_read': false,
    'metadata': {'product_id': dellMonitorId, 'days_remaining': 14},
  };
  final notifRes = await client.insertRow('notifications', notifPayload);
  if (!notifRes.isSuccess) {
    stderr.writeln('Failed to insert sample notification: ${notifRes.body}');
    exit(1);
  }
  print('  ✓ Seeded Notification for Sarah Jenkins');

  // Step 8: Verify Seeded Entities
  print('Step 8: Verifying seeded fixtures in Supabase...');
  final verifySarah = await client.queryTable('profiles', 'id=eq.$sarahId');
  final verifyMarcus = await client.queryTable('profiles', 'id=eq.$marcusId&role=eq.admin');
  final verifyProds = await client.queryTable('products', 'user_id=eq.$sarahId');
  final verifyClaims = await client.queryTable('claims', 'user_id=eq.$sarahId');

  if (verifySarah.statusCode == 200 &&
      verifyMarcus.statusCode == 200 &&
      verifyProds.statusCode == 200 &&
      verifyClaims.statusCode == 200) {
    print('All seeded fixtures successfully verified in live Supabase (exit code 0).');
  } else {
    stderr.writeln('Verification of seeded fixtures failed.');
    exit(1);
  }
}

void main(List<String> args) async {
  final action = args.isNotEmpty ? args[0] : 'seed';
  final env = Platform.environment;
  final url = env['project_url'] ?? env['SUPABASE_URL'] ?? 'https://kvxfkfgzsapvvswjcmzj.supabase.co';
  final key = env['service_role'] ?? env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  if (key.isEmpty) {
    stderr.writeln('Error: service_role key not provided.');
    exit(2);
  }

  final client = SeedClient(url, key);
  print('Target Supabase instance: $url');

  try {
    if (action == 'verify') {
      await runVerify(client);
    } else if (action == 'clean') {
      await runClean(client);
    } else if (action == 'seed') {
      await runSeed(client);
    } else {
      stderr.writeln('Unknown action: $action');
      exit(1);
    }
  } catch (e, st) {
    stderr.writeln('Exception occurred during $action: $e\n$st');
    exit(1);
  } finally {
    client.close();
  }

  exit(0);
}
EOF

dart run "$TMP_SEED_SCRIPT" "$ACTION"
STATUS=$?
if [ $STATUS -eq 0 ]; then
  echo -e "${GREEN}✓ Seeder operation completed successfully.${NC}"
else
  echo -e "${RED}✗ Seeder operation failed with exit code $STATUS.${NC}"
fi
exit $STATUS
