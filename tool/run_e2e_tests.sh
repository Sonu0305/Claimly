#!/usr/bin/env bash
# ==============================================================================
# Claimly Master E2E Test Suite Runner
# Usage:
#   ./tool/run_e2e_tests.sh --all
#   ./tool/run_e2e_tests.sh --tier <1|2|3|4>
#   ./tool/run_e2e_tests.sh --backend
#   ./tool/run_e2e_tests.sh --verbose
# ==============================================================================

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

RUN_TIER_1=false
RUN_TIER_2=false
RUN_TIER_3=false
RUN_TIER_4=false
RUN_BACKEND=false
RUN_INTEGRATION=false
VERBOSE=false

print_usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --all         Run complete E2E test suite (Backend Contracts + Tiers 1-4 + Integration)
  -t, --tier <N>    Run specific tier (1, 2, 3, or 4)
  -b, --backend     Run backend contract tests (DDL, RLS, Storage, Edge Functions)
  -i, --integration Run Flutter integration tests (integration_test/)
  -v, --verbose     Verbose test output
  -h, --help        Show this help message

Exit Codes:
  0                 All selected test suites passed
  1                 One or more test suites failed
  2                 Pre-flight environment failure
EOF
}

# Default to running all if no flags specified
if [ $# -eq 0 ]; then
  RUN_TIER_1=true
  RUN_TIER_2=true
  RUN_TIER_3=true
  RUN_TIER_4=true
  RUN_BACKEND=true
  RUN_INTEGRATION=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all)
      RUN_TIER_1=true
      RUN_TIER_2=true
      RUN_TIER_3=true
      RUN_TIER_4=true
      RUN_BACKEND=true
      RUN_INTEGRATION=true
      shift
      ;;
    -t|--tier)
      if [ -z "${2:-}" ]; then
        echo -e "${RED}Error: --tier requires an argument (1, 2, 3, or 4).${NC}"
        exit 2
      fi
      case "$2" in
        1) RUN_TIER_1=true ;;
        2) RUN_TIER_2=true ;;
        3) RUN_TIER_3=true ;;
        4) RUN_TIER_4=true ;;
        *) echo -e "${RED}Error: Invalid tier '$2'. Must be 1, 2, 3, or 4.${NC}"; exit 2 ;;
      esac
      shift 2
      ;;
    -b|--backend)
      RUN_BACKEND=true
      shift
      ;;
    -i|--integration)
      RUN_INTEGRATION=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      print_usage
      exit 2
      ;;
  esac
done

echo -e "\n${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}Claimly Opaque-Box E2E Test Suite Runner${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"

# Pre-flight check: Dart CLI
if ! command -v dart &> /dev/null; then
  echo -e "${RED}Pre-flight failure: 'dart' command not found in PATH.${NC}"
  exit 2
fi

# Pre-flight check: .env file
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo -e "${RED}Pre-flight failure: .env file not found in $PROJECT_DIR.${NC}"
  exit 2
fi

TOTAL_START=$(date +%s)
FAILED_SUITES=()
PASSED_SUITES=()

run_dart_test() {
  local suite_title="$1"
  local test_file="$2"

  echo -e "\n${BLUE}${BOLD}▶ Running: ${suite_title}${NC} (${test_file})"
  local SUITE_START=$(date +%s)

  local CMD="dart run $test_file"

  if eval "$CMD"; then
    local SUITE_END=$(date +%s)
    local DURATION=$((SUITE_END - SUITE_START))
    echo -e "${GREEN}✓ [PASS] ${suite_title} (${DURATION}s)${NC}"
    PASSED_SUITES+=("${suite_title}")
  else
    local SUITE_END=$(date +%s)
    local DURATION=$((SUITE_END - SUITE_START))
    echo -e "${RED}✗ [FAIL] ${suite_title} (${DURATION}s)${NC}"
    FAILED_SUITES+=("${suite_title}")
  fi
}

# 1. Backend Contracts
if [ "$RUN_BACKEND" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: BACKEND CONTRACT VERIFICATION (DDL, RLS, Storage, Functions)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  run_dart_test "Backend DDL & Triggers" "test/e2e/backend_contracts/database_ddl_test.dart"
  run_dart_test "Row Level Security (RLS)" "test/e2e/backend_contracts/rls_policies_test.dart"
  run_dart_test "Storage Buckets & Policies" "test/e2e/backend_contracts/storage_buckets_test.dart"
  run_dart_test "Edge Functions Contract" "test/e2e/backend_contracts/edge_functions_test.dart"
fi

# 2. Tier 1: Feature Coverage
if [ "$RUN_TIER_1" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: TIER 1 FEATURE COVERAGE (35 Cases across 7 Features)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  run_dart_test "Tier 1: Auth & Session Management" "test/e2e/tier1_feature_coverage/auth_feature_test.dart"
  run_dart_test "Tier 1: Product Management & Warranty" "test/e2e/tier1_feature_coverage/product_management_test.dart"
  run_dart_test "Tier 1: 5-Step Claim Filing Wizard" "test/e2e/tier1_feature_coverage/claim_wizard_test.dart"
  run_dart_test "Tier 1: Claims Management & Timeline" "test/e2e/tier1_feature_coverage/claim_timeline_test.dart"
  run_dart_test "Tier 1: Notifications & Expiry Alerts" "test/e2e/tier1_feature_coverage/notification_feed_test.dart"
  run_dart_test "Tier 1: PDF Export & Admin Analytics" "test/e2e/tier1_feature_coverage/pdf_export_test.dart"
  run_dart_test "Tier 1: Backend DDL & Security Contracts" "test/e2e/tier1_feature_coverage/backend_contract_tier1_test.dart"
fi

# 3. Tier 2: Boundary & Corner Cases
if [ "$RUN_TIER_2" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: TIER 2 BOUNDARY & CORNER CASES (35 Cases across 7 Areas)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  run_dart_test "Tier 2: Auth Boundary & Validation" "test/e2e/tier2_boundary_corner/auth_boundary_test.dart"
  run_dart_test "Tier 2: Product Boundary & Milestones" "test/e2e/tier2_boundary_corner/product_boundary_test.dart"
  run_dart_test "Tier 2: Wizard Boundary & File Limits" "test/e2e/tier2_boundary_corner/wizard_boundary_test.dart"
  run_dart_test "Tier 2: Claim Boundary & Grace Periods" "test/e2e/tier2_boundary_corner/claim_boundary_test.dart"
  run_dart_test "Tier 2: Notification Boundary & Offsets" "test/e2e/tier2_boundary_corner/notification_boundary_test.dart"
  run_dart_test "Tier 2: PDF & Analytics Boundary" "test/e2e/tier2_boundary_corner/pdf_analytics_boundary_test.dart"
  run_dart_test "Tier 2: Security & Backend Boundary" "test/e2e/tier2_boundary_corner/security_boundary_test.dart"
fi

# 4. Tier 3: Cross-Feature State Synchronization
if [ "$RUN_TIER_3" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: TIER 3 CROSS-FEATURE COMBINATIONS (15 Pairwise Cases)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  run_dart_test "Tier 3: Claim Lifecycle State Sync" "test/e2e/tier3_cross_feature/claim_lifecycle_state_sync_test.dart"
  run_dart_test "Tier 3: Warranty-to-Claim Pipeline" "test/e2e/tier3_cross_feature/warranty_to_claim_pipeline_test.dart"
  run_dart_test "Tier 3: Admin Actions & Subsystem Impacts" "test/e2e/tier3_cross_feature/admin_action_impact_test.dart"
  run_dart_test "Tier 3: Network Recovery & Profile Sync" "test/e2e/tier3_cross_feature/user_deletion_cascade_test.dart"
fi

# 5. Tier 4: Real-World User Journeys
if [ "$RUN_TIER_4" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: TIER 4 REAL-WORLD APPLICATION SCENARIOS (5 Complete Journeys)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  run_dart_test "Tier 4: Journey RW-01 Onboarding" "test/e2e/tier4_real_world/journey_new_customer_onboarding_test.dart"
  run_dart_test "Tier 4: Journey RW-02 Complete Claim Resolution" "test/e2e/tier4_real_world/journey_complete_claim_resolution_test.dart"
  run_dart_test "Tier 4: Journey RW-03 Admin Operations" "test/e2e/tier4_real_world/journey_admin_daily_operations_test.dart"
  run_dart_test "Tier 4: Journey RW-04 Expiry Alert to Action" "test/e2e/tier4_real_world/journey_warranty_alert_to_action_test.dart"
  run_dart_test "Tier 4: Journey RW-05 Concurrent Multi-Role" "test/e2e/tier4_real_world/journey_multi_device_role_handoff_test.dart"
fi

# 6. Flutter Integration Tests
if [ "$RUN_INTEGRATION" = true ]; then
  echo -e "\n${BOLD}================================================================${NC}"
  echo -e "${BOLD}PHASE: FLUTTER INTEGRATION TESTS (integration_test/)${NC}"
  echo -e "${BOLD}================================================================${NC}"
  local_pass=true
  INT_START=$(date +%s)
  for test_file in integration_test/*_test.dart; do
    local_title="Flutter Integration: $(basename "$test_file")"
    echo -e "\n${BLUE}${BOLD}▶ Running: ${local_title}${NC}"
    SUITE_START=$(date +%s)
    if flutter test -d flutter-tester "$test_file"; then
      SUITE_END=$(date +%s)
      SUITE_DURATION=$((SUITE_END - SUITE_START))
      echo -e "${GREEN}✓ [PASS] ${local_title} (${SUITE_DURATION}s)${NC}"
      PASSED_SUITES+=("${local_title}")
    else
      SUITE_END=$(date +%s)
      SUITE_DURATION=$((SUITE_END - SUITE_START))
      echo -e "${RED}✗ [FAIL] ${local_title} (${SUITE_DURATION}s)${NC}"
      FAILED_SUITES+=("${local_title}")
      local_pass=false
    fi
  done
  INT_END=$(date +%s)
  INT_DURATION=$((INT_END - INT_START))
fi

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

echo -e "\n${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}E2E TEST SUITE EXECUTION SUMMARY${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "Total Execution Time: ${TOTAL_DURATION}s"
echo -e "Passed Suites: ${GREEN}${#PASSED_SUITES[@]}${NC}"
for suite in "${PASSED_SUITES[@]}"; do
  echo -e "  ${GREEN}✓ ${suite}${NC}"
done

if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
  echo -e "\nFailed Suites: ${RED}${#FAILED_SUITES[@]}${NC}"
  for suite in "${FAILED_SUITES[@]}"; do
    echo -e "  ${RED}✗ ${suite}${NC}"
  done
  echo -e "\n${RED}${BOLD}E2E TEST RUN FAILED (Exit Code: 1)${NC}\n"
  exit 1
else
  echo -e "\n${GREEN}${BOLD}ALL E2E SUITES PASSED (Exit Code: 0)${NC}\n"
  exit 0
fi
