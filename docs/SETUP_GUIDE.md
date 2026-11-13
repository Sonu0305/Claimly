# Claimly — Developer & Operations Setup Guide

This guide provides end-to-end instructions for configuring, deploying, running, and verifying the **Claimly** automated warranty and refund claim assistant across local workstations, cloud environments, and CI/CD pipelines.

---

## 1. System Prerequisites

Ensure your host workstation satisfies the following software and platform requirements before initializing the repository:

### 1.1 Core Development Runtimes
- **Flutter SDK**: Version `>=3.19.0` (Verified on Flutter `3.38.9`).
  - Verify installation: `flutter --version`
  - Ensure Flutter doctor passes for your target platform: `flutter doctor`
- **Dart SDK**: Version `>=3.3.0` (Included with Flutter SDK, constraint: `'^3.10.0 <4.0.0'`).
  - Verify installation: `dart --version`
- **Supabase CLI**: Version `>=1.140.0` (Required for database migrations, local emulation, and Edge Function deployments).
  - Install via Homebrew: `brew install supabase/tap/supabase`
  - Install via npm: `npm install -g supabase`
  - Verify installation: `supabase --version`
- **Docker Engine**: Version `>=24.0.0` and **Docker Compose v2** (Required for the local Supabase container stack).
  - Verify installation: `docker --version && docker compose version`
- **Deno Runtime** (or Node.js `>=18.0.0`): Version `>=1.37.0` (Required for local TypeScript Edge Function development).
  - Verify installation: `deno --version`
- **Git**: Version `>=2.34.0`.

### 1.2 Platform-Specific Build Dependencies (Linux Desktop)
If executing the Flutter application on Linux desktop, install the native GTK and build toolchain:
```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
```

---

## 2. Workspace Initialization & Environment Configuration

### 2.1 Clone the Repository
Clone the repository to your local workspace and navigate to the project root:
```bash
git clone https://github.com/swayam-shah/Claimly.git
cd Claimly
```

### 2.2 Configure Environment Variables
Copy the provided `.env.example` template to `.env`:
```bash
cp .env.example .env
```

Open `.env` in your text editor and provide your Supabase project parameters:
```ini
APP_ENV=development
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-anon-token-here
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-service-role-token-here
DATABASE_URL=postgresql://postgres:your-db-password@db.your-project-ref.supabase.co:5432/postgres
```

> **Security Guardrail**: Never commit `.env` or paste your `SUPABASE_SERVICE_ROLE_KEY` into frontend client code. The Flutter client only consumes `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `lib/core/constants/supabase_config.dart`.

### 2.3 Install Flutter Dependencies & Generate Code
Install all Pub dependencies and run the build runner to generate Riverpod providers:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Database Migration & Backend Provisioning

Claimly supports two backend deployment modes: a **Local Docker Stack** or a **Remote Supabase Cloud Project**.

### Option A: Local Supabase Stack (Docker)
1. Initialize and launch the local containers (PostgreSQL 15+, PostgREST, GoTrue Auth, Realtime, Storage, Inbucket):
   ```bash
   supabase start
   ```
2. The local CLI automatically applies migrations from `supabase/migrations/20261111000000_claimly_schema.sql`.
3. To reset the database and re-apply migrations cleanly at any time:
   ```bash
   supabase db reset
   ```
4. Update your `.env` with the local credentials output by `supabase start` (typically `SUPABASE_URL=http://127.0.0.1:54321`).

### Option B: Remote Supabase Cloud Project
1. Authenticate with Supabase:
   ```bash
   supabase login
   ```
2. Link your local repository to your remote Supabase project reference:
   ```bash
   supabase link --project-ref <your-project-ref>
   ```
3. Push migrations and schema triggers to the cloud database:
   ```bash
   supabase db push
   ```
   *Alternatively, execute the standalone DDL in `supabase/schema.sql` via the Supabase Cloud SQL Editor.*

### Database Fixture Management (Seeding & Verification)
The repository provides an automated database management utility under `tool/seed_test_db.sh`:
- **Verify Schema, Tables, and Storage Buckets**:
  ```bash
  ./tool/seed_test_db.sh --verify
  ```
- **Populate Deterministic Test Personas (Sarah Jenkins & Marcus Vance)**:
  ```bash
  ./tool/seed_test_db.sh --seed
  ```
- **Clean Transient Test Fixtures**:
  ```bash
  ./tool/seed_test_db.sh --clean
  ```

---

## 4. Supabase Edge Functions Deployment

Deploy the 4 TypeScript/Deno Edge Functions located in `supabase/functions/` to your Supabase project:

```bash
# 1. Claim Processor (Submission validation, 7-day grace period, 0-100 priority scoring)
supabase functions deploy claim-processor --no-verify-jwt false

# 2. Warranty Expiry Checker (Daily cron inspecting 30/7/1-day milestones)
supabase functions deploy warranty-expiry-checker --no-verify-jwt false

# 3. Claim Analytics (Aggregates admin KPIs, status breakdown, 30-day timeline)
supabase functions deploy claim-analytics --no-verify-jwt false

# 4. Export Claim Report (Compiles denormalized claim bundle with verification code)
supabase functions deploy export-claim-report --no-verify-jwt false
```

### Local Testing of Edge Functions
To serve Edge Functions locally with Deno:
```bash
supabase functions serve --env-file .env
```

---

## 5. Running the Flutter Application

Launch the application on your desired target platform:

### 5.1 Google Chrome (Web)
```bash
flutter run -d chrome
```

### 5.2 Linux Desktop
```bash
flutter run -d linux
```

### 5.3 Android Emulator or Physical Device
Ensure your Android emulator is booted or physical device connected via USB debugging:
```bash
flutter devices
flutter run -d <device-id>
```

---

## 6. Comprehensive Test Execution Suite

Claimly features a 4-tier testing pyramid combined with hermetic unit tests, widget tests, integration tests, and backend contract validations.

### 6.1 Static Code Analysis & Linter Verification
Verify that the codebase complies with strict zero-warning, zero-error standards:
```bash
flutter analyze
```
*Expected result: `No issues found! (ran in ~7s)`*

### 6.2 Unit, Widget & Core Tests (123 Tests)
Run all co-located unit and widget tests:
```bash
# Execute entire core, unit, and widget suite
flutter test test/core/ test/unit/ test/widget/ test/widget_test.dart

# Run only unit tests
flutter test test/unit/

# Run only widget tests
flutter test test/widget/

# Run specific domain models or repositories
flutter test test/unit/models/product_model_test.dart
flutter test test/unit/repositories/claim_repository_test.dart
```
*Expected result: `+123: All tests passed!`*

### 6.3 Headless Flutter Integration Tests (3 Suites)
Execute the end-to-end integration flows using Flutter's integration test runner:
```bash
./tool/run_e2e_tests.sh -i
```
*Suites executed:*
1. `integration_test/auth_flow_test.dart` (Authentication, form validation, role routing)
2. `integration_test/claim_filing_flow_test.dart` (5-Step claim filing wizard, submission, claim detail)
3. `integration_test/product_crud_flow_test.dart` (Product registration, receipt upload, live countdown)

### 6.4 Master Opaque-Box E2E Suite (30 Suites, 110 Test Cases)
Run the master test runner across all 4 tiers and backend contracts:
```bash
./tool/run_e2e_tests.sh --all
```

#### Running Specific Test Tiers:
- **Backend Contracts (20 Cases)**:
  ```bash
  ./tool/run_e2e_tests.sh --backend
  ```
  *Validates PostgreSQL DDL, Row Level Security (RLS) isolation, 4 storage buckets, and Edge Function schemas.*

- **Tier 1: Feature Coverage (35 Cases)**:
  ```bash
  ./tool/run_e2e_tests.sh --tier 1
  ```
  *Validates auth flows, product management, claim wizard, timeline, notifications, and PDF export.*

- **Tier 2: Boundary & Corner Cases (35 Cases)**:
  ```bash
  ./tool/run_e2e_tests.sh --tier 2
  ```
  *Tests password boundaries, 7-day warranty grace periods, hazard NLP keyword bonuses (+25), attachment limits (20MB), and division-by-zero guards.*

- **Tier 3: Cross-Feature State Synchronization (15 Cases)**:
  ```bash
  ./tool/run_e2e_tests.sh --tier 3
  ```
  *Tests claim lifecycle sync, admin adjudication impact on analytics, and cascade deletions.*

- **Tier 4: Real-World User Journeys (5 Comprehensive Scenarios)**:
  ```bash
  ./tool/run_e2e_tests.sh --tier 4
  ```
  *Simulates Sarah Jenkins (Customer) and Marcus Vance (Admin) executing end-to-end resolution flows.*

---

## 7. Troubleshooting Common Setup Issues

| Problem | Root Cause | Recommended Fix |
|---|---|---|
| `flutter pub get` version mismatch on `intl` | Dependency conflict with transitive packages | Ensure `pubspec.yaml` specifies `intl: ^0.20.2`. Run `flutter pub upgrade intl`. |
| `supabase start` fails: Docker daemon not running | Docker Desktop / daemon is stopped | Start Docker daemon: `sudo systemctl start docker` or launch Docker Desktop. |
| Edge Function returns `401 Unauthorized` | Missing or invalid Supabase JWT in `Authorization` header | Ensure your HTTP client passes `Authorization: Bearer <token>` and `apikey: <anon_key>`. |
| Storage upload fails with `403 Forbidden` | Violating `${userId}/` folder isolation rule | Verify file path begins with the authenticated user's UUID: `receipts/${userId}/filename.pdf`. |
| `flutter analyze` reports generated file errors | Code generation files out of sync | Run `dart run build_runner build --delete-conflicting-outputs`. |
