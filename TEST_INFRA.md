# E2E Test Infra: Claimly — Automated Warranty & Refund Claim Assistant

## Test Philosophy
- **Opaque-Box & Requirement-Driven**: Tests interact exclusively through public observable interfaces (rendered UI widgets, GoRouter routes, Supabase PostgREST endpoints, Auth JWT flows, Storage APIs, Edge Functions, and generated PDF payloads). No test relies on private controller state, internal helper functions, or class internals.
- **Methodology**: Systematic 4-tier test case design combining Category-Partition, Boundary Value Analysis (BVA), Pairwise Combinatorial Testing, and Real-World Application Workload Testing.
- **Integrity Guarantee**: Strict zero-mock bypass for critical business logic. Assertions verify authentic database side effects, real PostgreSQL triggers, RLS tenant isolation, and live Edge Function validation results.

---

## Feature Inventory & Tier Mapping

| # | Feature | Source (Requirement) | Tier 1 (Coverage) | Tier 2 (Boundary) | Tier 3 (Pairwise) | Tier 4 (Real-World) |
|---|---------|---------------------|:-----------------:|:-----------------:|:-----------------:|:-------------------:|
| 1 | Auth, Session & Role Security | ORIGINAL_REQUEST §R4, PROJECT.md F17 | 5 cases | 5 cases | ✓ | ✓ |
| 2 | Product Inventory & Warranty Tracking | ORIGINAL_REQUEST §R4, PROJECT.md F19 | 5 cases | 5 cases | ✓ | ✓ |
| 3 | 5-Step Claim Filing Wizard | ORIGINAL_REQUEST §R4, PROJECT.md F20 | 5 cases | 5 cases | ✓ | ✓ |
| 4 | Claim Management, Timeline & Realtime | ORIGINAL_REQUEST §R4, PROJECT.md F21 | 5 cases | 5 cases | ✓ | ✓ |
| 5 | Notifications & Expiry Alert Pipeline | ORIGINAL_REQUEST §R2, §R4, PROJECT.md F23 | 5 cases | 5 cases | ✓ | ✓ |
| 6 | PDF Export & Admin Analytics | ORIGINAL_REQUEST §R2, §R4, PROJECT.md F22, F25 | 5 cases | 5 cases | ✓ | ✓ |
| 7 | Supabase DDL, RLS, Storage & Edge Functions | ORIGINAL_REQUEST §R1, §R2, PROJECT.md F1-10 | 5 cases | 5 cases | ✓ | ✓ |
| **Total** | **7 Major Feature Areas** | | **35 cases** | **35 cases** | **15 cases** | **5 journeys** |

*Overall Suite Size: 90 systematic test cases across 4 tiers.*

---

## Test Architecture

### 1. Test Runner & CLI Invocation
- **Master Test Runner Script**: `tool/run_e2e_tests.sh`
  - Execution: `./tool/run_e2e_tests.sh [options]`
  - Flags:
    - `--all`: Runs complete 4-tier suite + backend contract verification
    - `--tier <1|2|3|4>`: Runs only the specified tier (supports phased validation)
    - `--backend`: Runs database DDL, RLS, Storage, and Edge Function contract tests
    - `--verbose`: Emits detailed per-test assertions and timing
  - Pass/Fail Semantics: Strict exit code `0` if and only if 100% of executed tests pass; non-zero exit code (`1`) on any assertion or runtime failure.
- **Direct Flutter Test Runner**:
  - `flutter test test/e2e/` (runs all tests via standard Dart VM test runner)
  - `flutter test test/e2e/tier1_feature_coverage/`
  - `flutter test test/e2e/tier2_boundary_corner/`
  - `flutter test test/e2e/tier3_cross_feature/`
  - `flutter test test/e2e/tier4_real_world/`
  - `flutter test test/e2e/backend_contracts/`

### 2. Directory Layout
```
Claimly/
├── tool/
│   ├── run_e2e_tests.sh                      # Master CLI test runner
│   └── seed_test_db.sh                       # Test data seeder & cleaner
├── test/
│   ├── e2e/
│   │   ├── harness/                          # Opaque-box test harness & utilities
│   │   │   ├── app_harness.dart              # Boots ClaimlyApp headlessly
│   │   │   ├── backend_harness.dart          # HTTP PostgREST, Auth, Storage, Edge Functions
│   │   │   ├── ui_driver.dart                # High-level opaque user gestures
│   │   │   ├── test_data_seeder.dart         # Test fixtures & personas (Sarah, Marcus)
│   │   │   ├── test_keys.dart                # Semantic opaque UI keys
│   │   │   └── assertions.dart               # Opaque assertions for UI & contracts
│   │   ├── backend_contracts/                # Backend verification (M1 & M2 contracts)
│   │   │   ├── database_ddl_test.dart        # 6 tables, 4 enums, triggers, constraints
│   │   │   ├── rls_policies_test.dart        # Customer vs Admin isolation, privilege escalation
│   │   │   ├── edge_functions_test.dart      # claim-processor, warranty-expiry, analytics, export
│   │   │   └── storage_buckets_test.dart     # receipts, product-images, claim-attachments, avatars
│   │   ├── tier1_feature_coverage/           # Tier 1: ≥5 cases per feature (35 cases)
│   │   │   ├── auth_feature_test.dart
│   │   │   ├── product_management_test.dart
│   │   │   ├── claim_wizard_test.dart
│   │   │   ├── claim_timeline_test.dart
│   │   │   ├── notification_feed_test.dart
│   │   │   ├── pdf_export_test.dart
│   │   │   └── backend_contract_tier1_test.dart
│   │   ├── tier2_boundary_corner/            # Tier 2: Boundary & Corner cases (35 cases)
│   │   │   ├── auth_boundary_test.dart
│   │   │   ├── product_boundary_test.dart
│   │   │   ├── wizard_boundary_test.dart
│   │   │   ├── claim_boundary_test.dart
│   │   │   ├── notification_boundary_test.dart
│   │   │   ├── pdf_analytics_boundary_test.dart
│   │   │   └── security_boundary_test.dart
│   │   ├── tier3_cross_feature/              # Tier 3: Pairwise cross-feature combinations (15 cases)
│   │   │   ├── claim_lifecycle_state_sync_test.dart
│   │   │   ├── warranty_to_claim_pipeline_test.dart
│   │   │   ├── admin_action_impact_test.dart
│   │   │   └── user_deletion_cascade_test.dart
│   │   └── tier4_real_world/                 # Tier 4: Real-world application scenarios (5 journeys)
│   │       ├── journey_new_customer_onboarding_test.dart
│   │       ├── journey_complete_claim_resolution_test.dart
│   │       ├── journey_admin_daily_operations_test.dart
│   │       ├── journey_warranty_alert_to_action_test.dart
│   │       └── journey_multi_device_role_handoff_test.dart
```

### 3. Opaque-Box Test Harness Details
- **`app_harness.dart`**: Sets up `ClaimlyApp` in widget tests with optional Riverpod overrides, GoRouter initial location, and headless rendering environment.
- **`ui_driver.dart`**: Encapsulates user interactions:
  - `driver.signIn(email, password)`
  - `driver.register(name, email, password)`
  - `driver.addProduct(name, category, purchaseDate, warrantyMonths)`
  - `driver.completeClaimWizard(productId, claimType, title, description, attachments)`
  - `driver.updateClaimStatus(claimId, newStatus, adminNote)`
  - `driver.toggleTheme()`
- **`backend_harness.dart`**: Directly connects to PostgREST, Auth, and Edge Functions using standard HTTP client calls to verify backend contracts without coupling to Flutter code.

---

## 4-Tier Test Suite Specification

### Tier 1 — Feature Coverage (35 Test Cases)
Each feature has ≥5 isolated happy-path tests using equivalence class representatives:
1. **Auth & Session Management (TC-T1-AUTH-01 to 05)**:
   - TC-T1-AUTH-01: User registration with email/password creates customer profile.
   - TC-T1-AUTH-02: Valid credentials authenticate user and issue JWT session.
   - TC-T1-AUTH-03: Sign out clears active session and redirects to `/login`.
   - TC-T1-AUTH-04: Password reset request sends recovery email.
   - TC-T1-AUTH-05: Session persistence restores user state on cold boot.
2. **Product Inventory & Warranty Tracking (TC-T1-PROD-01 to 05)**:
   - TC-T1-PROD-01: Product registration with purchase date and warranty months calculates expiry.
   - TC-T1-PROD-02: Product list displays active inventory with search and category filtering.
   - TC-T1-PROD-03: Product details view displays warranty countdown badge and receipt.
   - TC-T1-PROD-04: Product update modifies attributes and recalculates expiry date.
   - TC-T1-PROD-05: Product deletion removes item from inventory.
3. **5-Step Claim Filing Wizard (TC-T1-WIZ-01 to 05)**:
   - TC-T1-WIZ-01: Step 1 product selector enables progression only on valid selection.
   - TC-T1-WIZ-02: Step 2 claim type selection accepts repair, replacement, or refund.
   - TC-T1-WIZ-03: Step 3 issue details captures title, description, and incident date.
   - TC-T1-WIZ-04: Step 4 proof attachments accepts up to 5 files.
   - TC-T1-WIZ-05: Step 5 review & submit dispatches claim, generates claim number, and redirects to details.
4. **Claim Management, Timeline & Realtime (TC-T1-CLM-01 to 05)**:
   - TC-T1-CLM-01: Claims feed lists user claims filterable by status badge.
   - TC-T1-CLM-02: Claim detail displays status header, timeline steps, and admin notes.
   - TC-T1-CLM-03: Admin claims review screen allows status updates and note entry.
   - TC-T1-CLM-04: Database trigger automatically inserts audit row into `claim_timeline`.
   - TC-T1-CLM-05: Supabase Realtime subscription reflects status update dynamically.
5. **Notifications & Expiry Alert Pipeline (TC-T1-NOTIF-01 to 05)**:
   - TC-T1-NOTIF-01: Expiry alerts created for warranties expiring in 30, 7, and 1 day(s).
   - TC-T1-NOTIF-02: Notification feed displays unread alerts with visual badges.
   - TC-T1-NOTIF-03: Marking notification as read decrements unread counter.
   - TC-T1-NOTIF-04: Claim status change trigger automatically creates user notification.
   - TC-T1-NOTIF-05: Expiry cron deduplication prevents multiple alerts on same day.
6. **PDF Export & Admin Analytics (TC-T1-RPT-01 to 05)**:
   - TC-T1-RPT-01: Client-side PDF export compiles claim report with QR verification code.
   - TC-T1-RPT-02: `export-claim-report` Edge Function returns structured denormalized payload.
   - TC-T1-RPT-03: Admin dashboard renders KPI summary cards (total, active, approval rate).
   - TC-T1-RPT-04: Admin interactive charts render status pie and type bar charts.
   - TC-T1-RPT-05: Admin user directory displays registered accounts with claims count.
7. **Database Schema, RLS & Edge Functions (TC-T1-BE-01 to 05)**:
   - TC-T1-BE-01: DDL schema contains 6 tables, 4 enums, constraints, and cascading rules.
   - TC-T1-BE-02: PostgreSQL triggers (`updated_at`, `handle_new_user`, `claim_number`) fire reliably.
   - TC-T1-BE-03: `claim-processor` Edge Function validates submission and calculates priority score.
   - TC-T1-BE-04: RLS policies isolate customer data across all 6 tables.
   - TC-T1-BE-05: Storage buckets enforce path policies and role access.

---

### Tier 2 — Boundary & Corner Cases (35 Test Cases)
Each feature area includes ≥5 boundary, edge, and error-rejection tests:
1. **Auth Boundaries (TC-T2-AUTH-01 to 05)**:
   - Password exactly 6 characters (valid boundary) vs 5 characters (rejected).
   - Malformed email strings (missing `@`, spaces, 255+ characters).
   - Mismatched password and confirm-password fields.
   - Unauthorized customer accessing `/admin/*` redirected to `/customer/home`.
   - Expired JWT token clears session and redirects to `/login`.
2. **Product Boundaries (TC-T2-PROD-01 to 05)**:
   - Warranty duration of 0 months or negative integer rejected.
   - Purchase date in the future rejected; purchase date today accepted.
   - Warranty expiry today (T+0) categorized as expiring/active.
   - Warranty expiry at 30 days (T+30) triggers expiry warning card.
   - Product name with unicode emojis and 100-character boundary handled cleanly.
3. **Wizard Boundaries (TC-T2-WIZ-01 to 05)**:
   - Wizard Step 1 with 0 registered products presents "Add Product" prompt.
   - Incident date prior to product purchase date rejected.
   - Incident date in future rejected.
   - Oversized attachment (>20MB) or invalid file extension (.exe) rejected.
   - Rapid double-tap on Step 5 submit button prevented via loading state idempotency.
4. **Claim Boundaries (TC-T2-CLM-01 to 05)**:
   - Incident date within 7-day grace period accepted with `in_grace_period` flag.
   - Incident date 8 days past warranty expiry rejected by `claim-processor`.
   - Hazard keywords (`smoke`, `fire`, `shock`) boost priority score by +25 points up to 100.
   - Empty claim history renders `EmptyStateView` with action button.
   - Non-admin user attempting direct status update via PostgREST blocked by RLS.
5. **Notification Boundaries (TC-T2-NOTIF-01 to 05)**:
   - Products expiring at T+31 or T+29 produce no alerts on daily cron.
   - Unread count > 99 renders as "99+" badge without layout overflow.
   - Notification feed with 0 records displays empty inbox illustration.
   - Marking foreign user's notification as read blocked by RLS.
   - Multiple status changes on same claim generate distinct chronological alerts.
6. **PDF & Analytics Boundaries (TC-T2-RPT-01 to 05)**:
   - PDF export for claim with 0 attachments generates successfully.
   - Analytics endpoint with 0 claims in database returns zeroed KPIs without divide-by-zero.
   - Customer token accessing `claim-analytics` rejected with HTTP 403 Forbidden.
   - Denormalized export API for foreign claim rejected with HTTP 403 Forbidden.
   - Extreme values (claim amount $0.00, $1,000,000.00) format correctly.
7. **Security & Backend Boundaries (TC-T2-BE-01 to 05)**:
   - Customer attempting direct PATCH `role='admin'` on `profiles` blocked by RLS/trigger.
   - Storage upload to private `receipts` bucket without Auth token returns HTTP 400/401.
   - PostgREST request with corrupted JWT signature returns HTTP 401 `PGRST301`.
   - SQL injection attempts in search queries safely sanitized by parameterized queries.
   - Cross-tenant delete: User A attempting DELETE on User B's product affects 0 rows.

---

### Tier 3 — Cross-Feature Combinations (15 Test Cases)
Pairwise interactions across independent subsystems:
- **TC-T3-PAIR-01**: Expiry Alert → Dashboard Card → Wizard Pre-population (T+7 alert leads to pre-selected product in Step 1).
- **TC-T3-PAIR-02**: Claim Submission → Edge Function Priority → Admin Queue Sorting.
- **TC-T3-PAIR-03**: Admin Status Approval → Database Trigger → Timeline Entry → Realtime Push → Customer UI Update.
- **TC-T3-PAIR-04**: Admin Status Update → Notification Creation → Decrement Unread on View.
- **TC-T3-PAIR-05**: Claim Resolution → PDF Export includes updated timeline and admin notes.
- **TC-T3-PAIR-06**: Product Deletion with Associated Claims cascades or prevents deletion per schema rules.
- **TC-T3-PAIR-07**: Auth Session Token Expiration during Step 4 Attachment Upload pauses and resumes after re-auth.
- **TC-T3-PAIR-08**: Customer Profile Avatar Upload updates both Storage bucket and profile avatar URL in App Bar.
- **TC-T3-PAIR-09**: Theme Toggle (Light ↔ Dark) persists across tab switches and app restarts.
- **TC-T3-PAIR-10**: Admin Claim Status Update dynamically updates Admin Analytics KPI cards.
- **TC-T3-PAIR-11**: Multi-filter combination: Products filtered simultaneously by category ("Electronics") and warranty status ("Expiring Soon").
- **TC-T3-PAIR-12**: Wizard Step 3 Severity Keywords + Step 4 Proof Attachment compound priority score.
- **TC-T3-PAIR-13**: Expiry cron execution alongside concurrent claim submission for same product.
- **TC-T3-PAIR-14**: Admin user directory reflects new user signup and incremented product/claim counts.
- **TC-T3-PAIR-15**: Customer submits claim while simultaneously viewing notifications in another tab.

---

### Tier 4 — Real-World Application Scenarios (5 Comprehensive End-to-End Journeys)

| # | Journey Scenario | Description & Workflow | Complexity |
|---|------------------|------------------------|------------|
| 1 | **RW-01: New Customer Onboarding & Product Lifecycle** | Sarah signs up, logs in, registers 2 products (1 active, 1 expiring in 15 days), observes dashboard expiry warning card, inspects product detail, and switches to Dark Mode. | High |
| 2 | **RW-02: Complete Claim Resolution & PDF Audit** | Sarah files a warranty claim via 5-step wizard with photos; Admin Marcus logs into Admin Shell, reviews claim, inspects photos, approves claim with resolution notes; Sarah receives realtime update and exports PDF report. | Very High |
| 3 | **RW-03: Admin Daily Operations & Analytics** | Admin Marcus logs in, reviews aggregated KPI cards and `fl_chart` charts, filters submitted claims by priority score, updates 3 claims across statuses, and inspects user directory. | High |
| 4 | **RW-04: Expiry Notification to Claim Action Pipeline** | Scheduled cron runs for T+7 expiry; Sarah receives push alert, taps alert to launch pre-filled Claim Wizard, submits claim under grace period rules, and verifies timeline tracking. | High |
| 5 | **RW-05: Multi-Role Concurrent Collaboration & Security Barrier** | Customer Sarah and Admin Marcus maintain concurrent sessions; Sarah attempts unauthorized access to `/admin` (blocked); Admin updates Sarah's claim; Sarah's timeline updates instantly over Realtime channel. | High |

---

## Coverage Thresholds & Pass Criteria

- **Tier 1 (Feature Coverage)**: ≥5 per feature (Total: 35 test cases)
- **Tier 2 (Boundary & Corner Cases)**: ≥5 per feature (Total: 35 test cases)
- **Tier 3 (Cross-Feature Combinations)**: 15 pairwise interaction cases
- **Tier 4 (Real-World Application Scenarios)**: 5 comprehensive end-user journeys
- **Backend Contract Verification**: 4 dedicated suites (DDL, RLS, Storage, Edge Functions)
- **Pass Criteria**: 100% test pass rate with exit code 0; zero compile or runtime errors; strict adherence to opaque-box boundaries.
