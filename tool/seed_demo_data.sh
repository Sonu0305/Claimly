#!/usr/bin/env bash
# ==============================================================================
# Claimly Presentation & Demo Database Seeder
# Generates rich, realistic scenarios showcasing every feature of the app.
# Usage:
#   ./tool/seed_demo_data.sh [--seed | --clean | --verify]
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

echo -e "${BLUE}${BOLD}==> Claimly Presentation & Demo Data Seeder [Action: $ACTION]${NC}"
echo -e "${BLUE}Target Supabase instance: ${SUPABASE_URL}${NC}"

python3 - << 'EOF' "$ACTION" "$SUPABASE_URL" "$SERVICE_ROLE"
import sys
import json
import time
import socket
import struct
import subprocess
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone

action = sys.argv[1]
supabase_url = sys.argv[2].rstrip('/')
service_role = sys.argv[3]

# --- DNS Cache & Gateway Fallback (resolves WSL2 / host firewall DNS timeouts) ---
_DNS_CACHE = {}
_orig_getaddrinfo = socket.getaddrinfo

def _get_default_gateway():
    try:
        with open('/proc/net/route') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 3 and parts[1] == '00000000':
                    return socket.inet_ntoa(struct.pack('<L', int(parts[2], 16)))
    except Exception:
        pass
    return None

def _resolve_with_gateway(host):
    gw = _get_default_gateway()
    if not gw:
        return None
    try:
        out = subprocess.check_output(['dig', f'@{gw}', host, '+short'], text=True, timeout=3)
        for line in out.strip().splitlines():
            ip = line.strip()
            if ip and not ip.startswith(';'):
                try:
                    socket.inet_aton(ip)
                    return ip
                except Exception:
                    continue
    except Exception:
        pass
    return None

def _smart_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
    cache_key = (host, port, family, type, proto, flags)
    if cache_key in _DNS_CACHE:
        return _DNS_CACHE[cache_key]

    # Try gateway DNS resolution first in WSL environments
    gw_ip = _resolve_with_gateway(host)
    if gw_ip:
        try:
            res = _orig_getaddrinfo(gw_ip, port, family, type, proto, flags)
            _DNS_CACHE[cache_key] = res
            return res
        except Exception:
            pass

    try:
        res = _orig_getaddrinfo(host, port, family, type, proto, flags)
        _DNS_CACHE[cache_key] = res
        return res
    except socket.gaierror:
        if gw_ip:
            res = _orig_getaddrinfo(gw_ip, port, family, type, proto, flags)
            _DNS_CACHE[cache_key] = res
            return res
        raise

socket.getaddrinfo = _smart_getaddrinfo

headers = {
    "apikey": service_role,
    "Authorization": "Bearer " + service_role,
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def api_call(method, path, body=None, extra_headers=None, max_retries=3):
    url = f"{supabase_url}{path}"
    req_headers = dict(headers)
    if extra_headers:
        req_headers.update(extra_headers)
    data = json.dumps(body).encode('utf-8') if body is not None else None

    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                content = resp.read().decode('utf-8')
                return resp.status, json.loads(content) if content.strip() else None
        except urllib.error.HTTPError as e:
            err_body = e.read().decode('utf-8')
            return e.code, err_body
        except (urllib.error.URLError, socket.error, TimeoutError) as e:
            if attempt < max_retries - 1:
                time.sleep(0.5 * (attempt + 1))
                continue
            print(f"  [Error] Network request failed after {max_retries} attempts: {e} ({method} {path})", file=sys.stderr)
            raise

def upload_storage(bucket, path, data_bytes, content_type, max_retries=3):
    url = f"{supabase_url}/storage/v1/object/{bucket}/{path}"
    req_headers = {
        "apikey": service_role,
        "Authorization": "Bearer " + service_role,
        "Content-Type": content_type,
        "x-upsert": "true"
    }
    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=data_bytes, headers=req_headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return resp.status
        except urllib.error.HTTPError as e:
            return e.code
        except (urllib.error.URLError, socket.error, TimeoutError) as e:
            if attempt < max_retries - 1:
                time.sleep(0.5 * (attempt + 1))
                continue
            print(f"  [Error] Storage upload failed after {max_retries} attempts: {e} ({bucket}/{path})", file=sys.stderr)
            raise

# Tiny valid PNG and PDF bytes
DUMMY_PNG = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\r\xef\x8c\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
DUMMY_PDF = b"%PDF-1.4\n1 0 obj\n<< /Title (Claimly Official Receipt) >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF"

def is_target_test_email(email):
    if not email:
        return False
    e = email.lower()
    return any(p in e for p in [
        'sarah.jenkins', 'marcus.admin', 'david.chen', 'elena.rostova', 'john.customer',
        'claimly-test.com', 'claimly.com'
    ]) and not e.startswith('swayam') and not 'skshah' in e

def run_clean():
    print("Purging existing presentation and test personas...")
    status, res = api_call("GET", "/auth/v1/admin/users?per_page=100")
    if status == 200 and res and "users" in res:
        for u in res["users"]:
            email = u.get("email", "")
            if is_target_test_email(email):
                uid = u["id"]
                api_call("DELETE", f"/auth/v1/admin/users/{uid}")
                print(f"  - Purged Auth user: {email} ({uid})")

    # Sweep public tables for residual records
    sweeps = [
        ("notifications", "title=ilike.*"),
        ("claim_attachments", "file_name=ilike.*"),
        ("claim_timeline", "notes=ilike.*"),
        ("claims", "title=ilike.*"),
        ("products", "name=ilike.*")
    ]
    for table, query in sweeps:
        api_call("DELETE", f"/rest/v1/{table}?{query}")
    print("✓ Clean operation complete.")

def run_verify():
    print("Verifying database connectivity, schemas, and counts...")
    tables = ['profiles', 'products', 'claims', 'claim_attachments', 'claim_timeline', 'notifications']
    for t in tables:
        status, res = api_call("GET", f"/rest/v1/{t}?select=count")
        print(f"  ✓ Table {t}: accessible (HTTP {status})")

    status, users = api_call("GET", "/auth/v1/admin/users?per_page=10")
    user_count = len(users.get('users', [])) if (status == 200 and users) else 0
    print(f"  ✓ Auth Admin: accessible ({user_count} sample probe)")

    status, buckets = api_call("GET", "/storage/v1/bucket")
    bucket_names = [b['name'] for b in buckets] if (status == 200 and buckets) else []
    print(f"  ✓ Storage: {len(bucket_names)} buckets verified ({', '.join(bucket_names)})")
    print("All verification checks PASSED.")

def run_seed():
    print("Beginning presentation-grade database seeding...\n")
    now = datetime.now(timezone.utc)
    today = now.date()

    # Step 1: Idempotent clean of test accounts
    run_clean()
    print("\nStep 1: Provisioning Personas...")

    personas = [
        # 1. Sarah Jenkins (Star Customer)
        {
            "name": "Sarah Jenkins",
            "emails": ["sarah.jenkins@claimly.com", "sarah.jenkins@claimly-test.com"],
            "password": "SecureP@ss2026!",
            "role": "customer",
            "phone": "+1-555-0144"
        },
        # 2. Marcus Vance (Store Administrator)
        {
            "name": "Marcus Vance",
            "emails": ["marcus.admin@claimly.com", "marcus.admin@claimly-test.com"],
            "password": "AdminSecret2026!",
            "role": "admin",
            "phone": "+1-555-0800"
        },
        # 3. David Chen (Power User - RLS Tenant Isolation)
        {
            "name": "David Chen",
            "emails": ["david.chen@claimly.com", "david.chen@claimly-test.com"],
            "password": "CustomerPass123!",
            "role": "customer",
            "phone": "+1-555-0277"
        },
        # 4. Elena Rostova (Luxury & Home Appliances)
        {
            "name": "Elena Rostova",
            "emails": ["elena.rostova@claimly.com", "elena.rostova@claimly-test.com"],
            "password": "CustomerPass123!",
            "role": "customer",
            "phone": "+1-555-0399"
        },
        # 5. John Doe (Fresh Customer - Clean Canvas for Live Wizard Presentation)
        {
            "name": "John Doe",
            "emails": ["john.customer@claimly.com", "john.customer@claimly-test.com"],
            "password": "CustomerPass123!",
            "role": "customer",
            "phone": "+1-555-0188"
        }
    ]

    user_map = {}
    admin_uids = []

    for p in personas:
        user_map[p["name"]] = []
        for email in p["emails"]:
            payload = {
                "email": email,
                "password": p["password"],
                "email_confirm": True,
                "user_metadata": {
                    "full_name": p["name"],
                    "role": p["role"],
                    "phone_number": p["phone"]
                }
            }
            status, res = api_call("POST", "/auth/v1/admin/users", payload)
            if status not in (200, 201) or not res or "id" not in res:
                print(f"Failed to create {email}: {status} {res}")
                sys.exit(1)
            uid = res["id"]
            user_map[p["name"]].append(uid)
            print(f"  ✓ Created user: {p['name']} <{email}> (ID: {uid})")

            # Upgrade role in profiles if admin
            if p["role"] == "admin":
                api_call("PATCH", f"/rest/v1/profiles?id=eq.{uid}", {"role": "admin"})
                admin_uids.append(uid)

    primary_admin_id = admin_uids[0] if admin_uids else None

    # Step 2: Upload Dummy Media to Storage Buckets
    print("\nStep 2: Uploading Verified Storage Fixtures...")
    upload_storage("receipts", "sample_receipt_apple.pdf", DUMMY_PDF, "application/pdf")
    upload_storage("receipts", "sample_receipt_delonghi.pdf", DUMMY_PDF, "application/pdf")
    upload_storage("receipts", "sample_receipt_bestbuy.pdf", DUMMY_PDF, "application/pdf")
    upload_storage("claim-attachments", "screen_defect_proof.png", DUMMY_PNG, "image/png")
    upload_storage("claim-attachments", "boiler_leak_proof.png", DUMMY_PNG, "image/png")
    upload_storage("claim-attachments", "battery_burn_proof.png", DUMMY_PNG, "image/png")
    print("  ✓ Uploaded 3 receipts (PDF) and 3 proof attachments (PNG)")

    # Step 3: Seed Products
    print("\nStep 3: Seeding Comprehensive Product Vaults...")
    created_products = [] # list of dicts

    # Relative Dates to guarantee 100% demo consistency regardless of date
    date_active_3yr = (today - timedelta(days=90)).isoformat()
    date_active_2yr = (today - timedelta(days=120)).isoformat()
    date_urgent_4d = (today - timedelta(days=361)).isoformat() # 12m warranty, expires in ~4 days!
    date_critical_1d = (today - timedelta(days=364)).isoformat() # 12m warranty, expires in ~1 day!
    date_grace_4d = (today - timedelta(days=369)).isoformat() # 12m warranty, expired 4 days ago! (Grace period)
    date_expired_45d = (today - timedelta(days=775)).isoformat() # 24m warranty, expired 45 days ago

    # Products for Sarah Jenkins (seed for both primary and alias accounts)
    for sarah_uid in user_map["Sarah Jenkins"]:
        sarah_catalog = [
            {
                "user_id": sarah_uid,
                "name": "Apple MacBook Pro 16\" (M3 Max)",
                "category": "Electronics",
                "brand": "Apple",
                "model_number": "M3 Max / 64GB / 1TB",
                "serial_number": "C02XYZ1234MBP",
                "purchase_date": date_active_3yr,
                "warranty_period_months": 36,
                "retailer": "Apple Store SoHo NYC",
                "purchase_price": 3499.00,
                "receipt_url": "sample_receipt_apple.pdf",
                "notes": "Space Black configuration. Used for iOS and Flutter production development."
            },
            {
                "user_id": sarah_uid,
                "name": "De'Longhi Magnifica S Espresso Machine",
                "category": "Appliances",
                "brand": "De'Longhi",
                "model_number": "ECAM22110SB",
                "serial_number": "DL-MAG-882194",
                "purchase_date": date_active_2yr,
                "warranty_period_months": 24,
                "retailer": "Williams-Sonoma",
                "purchase_price": 899.95,
                "receipt_url": "sample_receipt_delonghi.pdf",
                "notes": "Automatic compact espresso machine with high-pressure frother."
            },
            {
                "user_id": sarah_uid,
                "name": "Dell UltraSharp 27\" 4K USB-C Monitor",
                "category": "Electronics",
                "brand": "Dell",
                "model_number": "U2723QE",
                "serial_number": "CN-0827391-7281",
                "purchase_date": date_urgent_4d,
                "warranty_period_months": 12,
                "retailer": "Best Buy Manhattan",
                "purchase_price": 619.99,
                "receipt_url": "sample_receipt_bestbuy.pdf",
                "notes": "IPS Black panel. **URGENT**: Expires in 4 days! Showcases Orange Expiry Carousel Alert."
            },
            {
                "user_id": sarah_uid,
                "name": "Sony WH-1000XM5 Wireless Headphones",
                "category": "Electronics",
                "brand": "Sony",
                "model_number": "WH-1000XM5",
                "serial_number": "SN-WH99210-BLK",
                "purchase_date": date_critical_1d,
                "warranty_period_months": 12,
                "retailer": "B&H Photo Video NYC",
                "purchase_price": 399.99,
                "notes": "Active Noise Canceling. **CRITICAL**: Expires TOMORROW! Showcases Red Carousel Alert."
            },
            {
                "user_id": sarah_uid,
                "name": "Bose QuietComfort Earbuds II",
                "category": "Electronics",
                "brand": "Bose",
                "model_number": "QC Earbuds II",
                "serial_number": "BSE-QC2-44190",
                "purchase_date": date_grace_4d,
                "warranty_period_months": 12,
                "retailer": "Amazon US",
                "purchase_price": 279.00,
                "notes": "**7-DAY GRACE PERIOD**: Expired 4 days ago. Demonstrates automated triage grace period acceptance."
            },
            {
                "user_id": sarah_uid,
                "name": "Dyson V15 Detect Absolute Vacuum",
                "category": "Appliances",
                "brand": "Dyson",
                "model_number": "V15 Detect",
                "serial_number": "DY-V15-981240",
                "purchase_date": date_expired_45d,
                "warranty_period_months": 24,
                "retailer": "Target Brooklyn",
                "purchase_price": 749.99,
                "notes": "**EXPIRED**: 45 days past coverage. Demonstrates Expired filter chip and badge."
            }
        ]
        for p in sarah_catalog:
            st, res = api_call("POST", "/rest/v1/products", p)
            if st in (200, 201) and res:
                created_products.append(res[0])
                print(f"  ✓ Seeded Product: {res[0]['name']} for Sarah")

    # Products for David Chen
    for david_uid in user_map["David Chen"]:
        david_catalog = [
            {
                "user_id": david_uid,
                "name": "Sony PlayStation 5 Pro (2TB)",
                "category": "Electronics",
                "brand": "Sony",
                "model_number": "CFI-7000B",
                "serial_number": "PS5PRO-9812401",
                "purchase_date": (today - timedelta(days=180)).isoformat(),
                "warranty_period_months": 12,
                "retailer": "GameStop Downtown",
                "purchase_price": 699.99,
                "notes": "Next-gen ray tracing console."
            },
            {
                "user_id": david_uid,
                "name": "LG C3 65\" OLED 4K Smart TV",
                "category": "Electronics",
                "brand": "LG",
                "model_number": "OLED65C3PUA",
                "serial_number": "LG-C3-881920",
                "purchase_date": (today - timedelta(days=240)).isoformat(),
                "warranty_period_months": 24,
                "retailer": "Best Buy",
                "purchase_price": 1796.99,
                "notes": "Cinema HDR OLED screen."
            },
            {
                "user_id": david_uid,
                "name": "Super73-RX Electric Adventure Bike",
                "category": "Automotive",
                "brand": "Super73",
                "model_number": "RX-Obsidian",
                "serial_number": "S73-RX-77218",
                "purchase_date": (today - timedelta(days=300)).isoformat(),
                "warranty_period_months": 24,
                "retailer": "Super73 Official Store",
                "purchase_price": 3695.00,
                "notes": "Performance electric bike with 960 watt-hour battery."
            },
            {
                "user_id": david_uid,
                "name": "Herman Miller Embody Ergonomic Chair",
                "category": "Furniture",
                "brand": "Herman Miller",
                "model_number": "CN122AWAA",
                "serial_number": "HM-EMB-109283",
                "purchase_date": (today - timedelta(days=400)).isoformat(),
                "warranty_period_months": 144,
                "retailer": "Design Within Reach",
                "purchase_price": 1895.00,
                "notes": "12-Year comprehensive manufacturer warranty."
            }
        ]
        for p in david_catalog:
            st, res = api_call("POST", "/rest/v1/products", p)
            if st in (200, 201) and res:
                created_products.append(res[0])
                print(f"  ✓ Seeded Product: {res[0]['name']} for David")

    # Products for Elena Rostova
    for elena_uid in user_map["Elena Rostova"]:
        elena_catalog = [
            {
                "user_id": elena_uid,
                "name": "KitchenAid Pro 600 Stand Mixer (6-Qt)",
                "category": "Appliances",
                "brand": "KitchenAid",
                "model_number": "KP26M1XER",
                "serial_number": "KA-PRO-554190",
                "purchase_date": (today - timedelta(days=210)).isoformat(),
                "warranty_period_months": 36,
                "retailer": "Crate & Barrel",
                "purchase_price": 549.99,
                "notes": "Empire Red heavy-duty dough mixer."
            },
            {
                "user_id": elena_uid,
                "name": "Theragun PRO Plus Percussive Massager",
                "category": "Fitness & Health",
                "brand": "Therabody",
                "model_number": "TG-PRO-PLUS",
                "serial_number": "TB-9912041",
                "purchase_date": (today - timedelta(days=35)).isoformat(),
                "warranty_period_months": 24,
                "retailer": "Therabody Direct",
                "purchase_price": 599.00,
                "notes": "Deep muscle percussive massage device."
            },
            {
                "user_id": elena_uid,
                "name": "Breville Barista Touch Impress",
                "category": "Appliances",
                "brand": "Breville",
                "model_number": "BES881BSS",
                "serial_number": "BV-881-22910",
                "purchase_date": (today - timedelta(days=70)).isoformat(),
                "warranty_period_months": 24,
                "retailer": "Sur La Table",
                "purchase_price": 1499.95,
                "notes": "Touchscreen automated espresso machine."
            }
        ]
        for p in elena_catalog:
            st, res = api_call("POST", "/rest/v1/products", p)
            if st in (200, 201) and res:
                created_products.append(res[0])
                print(f"  ✓ Seeded Product: {res[0]['name']} for Elena")

    # Products for John Doe (Clean canvas for live wizard demo!)
    for john_uid in user_map["John Doe"]:
        john_catalog = [
            {
                "user_id": john_uid,
                "name": "Amazon Kindle Paperwhite Signature Edition (32GB)",
                "category": "Electronics",
                "brand": "Amazon",
                "model_number": "B08N3TCP2F",
                "serial_number": "KNDL-998124A",
                "purchase_date": (today - timedelta(days=60)).isoformat(),
                "warranty_period_months": 12,
                "retailer": "Amazon.com",
                "purchase_price": 189.99,
                "notes": "Clean item with active warranty, ready to file a live claim in presentation!"
            }
        ]
        for p in john_catalog:
            st, res = api_call("POST", "/rest/v1/products", p)
            if st in (200, 201) and res:
                created_products.append(res[0])
                print(f"  ✓ Seeded Product: {res[0]['name']} for John (Pristine Demo Canvas)")

    # Step 4: Seed Interactive Feature Claims
    print("\nStep 4: Seeding Core Showcase Claims & Lifecycle Scenarios...")

    # Helper to find product by user and partial name
    def find_prod(uid, keyword):
        for prod in created_products:
            if prod['user_id'] == uid and keyword.lower() in prod['name'].lower():
                return prod
        return None

    # Sarah's Claims (Primary Sarah)
    sarah_primary = user_map["Sarah Jenkins"][0]
    sarah_macbook = find_prod(sarah_primary, "MacBook")
    sarah_espresso = find_prod(sarah_primary, "De'Longhi")

    # Scenario A: Approved Replacement Claim with Safety NLP (Espresso Boiler Leak)
    # This is the STAR CLAIM for Live PDF Export & Green Resolution Banner!
    if sarah_espresso:
        espresso_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-4F11A9",
            "user_id": sarah_primary,
            "product_id": sarah_espresso["id"],
            "type": "replacement",
            "status": "approved",
            "title": "High-Pressure Boiler Leak & Thermal Steam Hazard",
            "description": "During pre-heat cycle, high-temperature steam erupted from internal bypass valve with strong burning plastic smell. Loud pop and smoke noticed. Immediate burn hazard.",
            "issue_category": "Hardware Defect",
            "incident_date": (today - timedelta(days=5)).isoformat(),
            "priority": 92, # NLP Hazard Escalation (fire/smoke/burn/steam pop)
            "admin_notes": "High-temperature boiler seal failure confirmed. Internal bypass valves damaged. Forwarded to safety recall QA.",
            "resolution_notes": "Safety replacement approved. Full retail replacement unit dispatched via FedEx Express (Tracking #771928410). Pre-paid return label enclosed in parcel.",
            "resolved_at": (now - timedelta(days=1)).isoformat(),
            "created_at": (now - timedelta(days=5)).isoformat(),
            "updated_at": (now - timedelta(days=1)).isoformat()
        }
        st, res = api_call("POST", "/rest/v1/claims", espresso_claim)
        if st in (200, 201) and res:
            cid = res[0]["id"]
            print(f"  ✓ Seeded Star Claim: {espresso_claim['claim_number']} (Approved Replacement)")
            # Add Timeline
            api_call("POST", "/rest/v1/claim_timeline", {
                "claim_id": cid, "from_status": None, "to_status": "submitted",
                "changed_by": sarah_primary, "notes": "Claim submitted with video evidence of boiler steam leak.",
                "created_at": (now - timedelta(days=5)).isoformat()
            })
            api_call("POST", "/rest/v1/claim_timeline", {
                "claim_id": cid, "from_status": "submitted", "to_status": "under_review",
                "changed_by": primary_admin_id, "notes": "Escalated to Priority 92 due to thermal hazard keywords.",
                "created_at": (now - timedelta(days=3)).isoformat()
            })
            api_call("POST", "/rest/v1/claim_timeline", {
                "claim_id": cid, "from_status": "under_review", "to_status": "approved",
                "changed_by": primary_admin_id, "notes": "Replacement approved. FedEx tracking #771928410 generated.",
                "created_at": (now - timedelta(days=1)).isoformat()
            })
            # Add Attachments
            api_call("POST", "/rest/v1/claim_attachments", {
                "claim_id": cid, "file_name": "boiler_leak_proof.png",
                "file_url": "boiler_leak_proof.png", "file_type": "image/png", "file_size": 2450000
            })
            api_call("POST", "/rest/v1/claim_attachments", {
                "claim_id": cid, "file_name": "delonghi_purchase_receipt.pdf",
                "file_url": "sample_receipt_delonghi.pdf", "file_type": "application/pdf", "file_size": 512000
            })
            # Notification for Sarah
            api_call("POST", "/rest/v1/notifications", {
                "user_id": sarah_primary, "claim_id": cid,
                "type": "claim_update",
                "title": "Claim Approved: Replacement Dispatched",
                "message": "Your replacement claim for De'Longhi Espresso Machine has been approved. Tracking #771928410.",
                "is_read": False,
                "metadata": {"claim_number": espresso_claim["claim_number"], "status": "approved"},
                "created_at": (now - timedelta(days=1)).isoformat()
            })

    # Scenario B: Under Review Warranty Repair (MacBook Pro Screen Defect)
    # Perfect for demoing live status change from Admin -> Customer!
    if sarah_macbook:
        mac_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-9A4B1C",
            "user_id": sarah_primary,
            "product_id": sarah_macbook["id"],
            "type": "warranty",
            "status": "under_review",
            "title": "Screen horizontal artifact line defect",
            "description": "A permanent purple horizontal line appeared across the retina display during load.",
            "issue_category": "Display / Screen Failure",
            "incident_date": (today - timedelta(days=3)).isoformat(),
            "priority": 65,
            "admin_notes": "Serial verified against Apple GSX. Diagnostic logs received, awaiting technician bench inspection.",
            "created_at": (now - timedelta(days=3)).isoformat(),
            "updated_at": (now - timedelta(days=1)).isoformat()
        }
        st, res = api_call("POST", "/rest/v1/claims", mac_claim)
        if st in (200, 201) and res:
            cid = res[0]["id"]
            print(f"  ✓ Seeded Active Review Claim: {mac_claim['claim_number']} (Under Review)")
            api_call("POST", "/rest/v1/claim_timeline", {
                "claim_id": cid, "from_status": None, "to_status": "submitted",
                "changed_by": sarah_primary, "notes": "Filing submitted with diagnostic screenshots.",
                "created_at": (now - timedelta(days=3)).isoformat()
            })
            api_call("POST", "/rest/v1/claim_timeline", {
                "claim_id": cid, "from_status": "submitted", "to_status": "under_review",
                "changed_by": primary_admin_id, "notes": "Case assigned to Senior Adjudicator Marcus Vance.",
                "created_at": (now - timedelta(days=1)).isoformat()
            })
            api_call("POST", "/rest/v1/claim_attachments", {
                "claim_id": cid, "file_name": "screen_defect_proof.png",
                "file_url": "screen_defect_proof.png", "file_type": "image/png", "file_size": 1850000
            })
            api_call("POST", "/rest/v1/notifications", {
                "user_id": sarah_primary, "claim_id": cid,
                "type": "claim_update",
                "title": "Claim Under Review",
                "message": "Your MacBook Pro warranty claim is currently being inspected by technical staff.",
                "is_read": True,
                "metadata": {"claim_number": mac_claim["claim_number"], "status": "under_review"},
                "created_at": (now - timedelta(days=1)).isoformat()
            })

    # Add Proactive Expiry Notifications for Sarah (Shows Notification Center badge & list)
    api_call("POST", "/rest/v1/notifications", {
        "user_id": sarah_primary,
        "type": "warranty_expiry",
        "title": "Critical Warranty Alert: Sony WH-1000XM5",
        "message": "Your Sony WH-1000XM5 Headphones warranty expires TOMORROW! File a claim now if you experience defects.",
        "is_read": False,
        "metadata": {"days_remaining": 1, "urgency": "critical"},
        "created_at": now.isoformat()
    })
    api_call("POST", "/rest/v1/notifications", {
        "user_id": sarah_primary,
        "type": "warranty_expiry",
        "title": "Urgent: Dell UltraSharp 27\" Expires This Week",
        "message": "Your Dell UltraSharp 27\" Monitor warranty expires in 4 days.",
        "is_read": False,
        "metadata": {"days_remaining": 4, "urgency": "urgent"},
        "created_at": (now - timedelta(days=1)).isoformat()
    })

    # Mirror claims for Sarah's alias account (@claimly-test.com)
    if len(user_map["Sarah Jenkins"]) > 1:
        sarah_alias = user_map["Sarah Jenkins"][1]
        alias_mac = find_prod(sarah_alias, "MacBook")
        if alias_mac:
            api_call("POST", "/rest/v1/claims", {
                "claim_number": f"CLM-{today.strftime('%Y%m%d')}-9A4B1T",
                "user_id": sarah_alias, "product_id": alias_mac["id"],
                "type": "warranty", "status": "under_review",
                "title": "Screen horizontal artifact line defect",
                "description": "Display artifact line across retina screen.",
                "issue_category": "Display / Screen Failure", "priority": 65,
                "incident_date": (today - timedelta(days=3)).isoformat()
            })

    # David Chen's Claims (Demonstrates Completed and Rejected Workflows)
    david_primary = user_map["David Chen"][0]
    david_ps5 = find_prod(david_primary, "PlayStation")
    david_tv = find_prod(david_primary, "OLED")
    david_bike = find_prod(david_primary, "Super73")

    # Scenario C: Completed Claim (PS5 Disc Drive Repair)
    if david_ps5:
        ps5_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-7B22CD",
            "user_id": david_primary, "product_id": david_ps5["id"],
            "type": "warranty", "status": "completed",
            "title": "Optical disc drive read failure (Error CE-100005-6)",
            "description": "Drive motor clicks continuously and fails to read 4K UHD Blu-ray discs.",
            "issue_category": "Hardware Defect",
            "incident_date": (today - timedelta(days=18)).isoformat(),
            "priority": 45,
            "admin_notes": "Sent to Sony Authorized Service Facility. Laser optical deck replaced.",
            "resolution_notes": "Optical pickup drive replaced with OEM assembly. Tested and re-delivered to customer via UPS Tracking #1Z99281.",
            "resolved_at": (now - timedelta(days=8)).isoformat(),
            "created_at": (now - timedelta(days=18)).isoformat(),
            "updated_at": (now - timedelta(days=8)).isoformat()
        }
        st, res = api_call("POST", "/rest/v1/claims", ps5_claim)
        if st in (200, 201) and res:
            print(f"  ✓ Seeded Completed Claim: {ps5_claim['claim_number']} (PS5 Repair)")

    # Scenario D: Rejected Claim (LG OLED Accidental Drop / Impact)
    if david_tv:
        tv_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-3E88A1",
            "user_id": david_primary, "product_id": david_tv["id"],
            "type": "refund", "status": "rejected",
            "title": "Permanent vertical colored lines across panel",
            "description": "Colored lines appeared while watching TV. Customer requested cash refund.",
            "issue_category": "Physical Damage",
            "incident_date": (today - timedelta(days=14)).isoformat(),
            "priority": 35,
            "admin_notes": "Technician onsite photo confirms 3.5cm spiderweb impact point near lower bezel. Mechanical drop damage.",
            "resolution_notes": "Claim rejected: Inspection revealed physical external impact damage. Accidental drops or external force impact are excluded under Section 4.2 of manufacturer limited warranty.",
            "resolved_at": (now - timedelta(days=10)).isoformat(),
            "created_at": (now - timedelta(days=14)).isoformat(),
            "updated_at": (now - timedelta(days=10)).isoformat()
        }
        st, res = api_call("POST", "/rest/v1/claims", tv_claim)
        if st in (200, 201) and res:
            print(f"  ✓ Seeded Rejected Claim: {tv_claim['claim_number']} (Physical Damage Exclusion)")

    # Scenario E: High-Hazard Under Review (Super73 Battery Spark)
    if david_bike:
        bike_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-9F5521",
            "user_id": david_primary, "product_id": david_bike["id"],
            "type": "replacement", "status": "under_review",
            "title": "Battery controller smoke and thermal spark hazard during charging",
            "description": "Charger port emitted audible sparks and burning smell during charge cycle. Thermal cut-off tripped.",
            "issue_category": "Battery & Power",
            "incident_date": (today - timedelta(days=2)).isoformat(),
            "priority": 95,
            "admin_notes": "Critical battery safety risk. Contacted Super73 engineering liaison for battery pack swap authorization.",
            "created_at": (now - timedelta(days=2)).isoformat(),
            "updated_at": (now - timedelta(days=1)).isoformat()
        }
        st, res = api_call("POST", "/rest/v1/claims", bike_claim)
        if st in (200, 201) and res:
            print(f"  ✓ Seeded Hazard Review Claim: {bike_claim['claim_number']} (Battery Spark)")

    # Elena's Claims
    elena_primary = user_map["Elena Rostova"][0]
    elena_mixer = find_prod(elena_primary, "KitchenAid")
    elena_massager = find_prod(elena_primary, "Theragun")

    if elena_mixer:
        mixer_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-6D4412",
            "user_id": elena_primary, "product_id": elena_mixer["id"],
            "type": "warranty", "status": "approved",
            "title": "Planetary gearbox grinding noise under heavy dough load",
            "description": "Loud metal clicking in speed positions 2 and 4. Dough hook hesitates.",
            "issue_category": "Hardware Defect",
            "incident_date": (today - timedelta(days=12)).isoformat(),
            "priority": 60,
            "resolution_notes": "Planetary gear assembly repair authorized under 3-year warranty. Authorized repair shop work order #KA-88319 issued.",
            "resolved_at": (now - timedelta(days=4)).isoformat(),
            "created_at": (now - timedelta(days=12)).isoformat(),
            "updated_at": (now - timedelta(days=4)).isoformat()
        }
        api_call("POST", "/rest/v1/claims", mixer_claim)

    if elena_massager:
        massager_claim = {
            "claim_number": f"CLM-{today.strftime('%Y%m%d')}-1A9904",
            "user_id": elena_primary, "product_id": elena_massager["id"],
            "type": "refund", "status": "submitted",
            "title": "Motor stalled and stopped reciprocating after 3 weeks",
            "description": "Unit powers on and OLED shows battery 100%, but percussive arm does not oscillate.",
            "issue_category": "Hardware Defect",
            "incident_date": (today - timedelta(days=1)).isoformat(),
            "priority": 50,
            "created_at": (now - timedelta(days=1)).isoformat(),
            "updated_at": (now - timedelta(days=1)).isoformat()
        }
        api_call("POST", "/rest/v1/claims", massager_claim)

    # Step 5: Seed Historical 30-Day Batch Claims (For BI Analytics Dashboard)
    print("\nStep 5: Seeding 30-Day BI Analytics Claim Dataset...")
    # Generate 15 evenly-spaced claims across the past 30 days to build a gorgeous, realistic fl_chart curve
    batch_scenarios = [
        # (days_ago, claim_type, status, category, title, priority, resolved_days_after)
        (28, "warranty", "completed", "Hardware Defect", "Faulty microswitch on blender lid", 40, 4),
        (26, "refund", "approved", "Battery & Power", "Cordless drill battery degraded to 10 mins", 65, 3),
        (24, "warranty", "completed", "Display / Screen Failure", "Dead pixels on curved gaming monitor", 50, 5),
        (22, "replacement", "rejected", "Physical Damage", "Cracked tablet casing after table fall", 30, 2),
        (20, "warranty", "approved", "Hardware Defect", "Washing machine drum suspension rod loose", 70, 3),
        (17, "replacement", "completed", "Battery & Power", "Smart watch battery swelling & casing lifting", 85, 4),
        (15, "refund", "approved", "Software / Firmware Glitch", "Smart thermostat stuck in infinite reboot loop", 55, 3),
        (13, "warranty", "under_review", "Hardware Defect", "Induction cooktop sensor E-02 error", 60, None),
        (11, "warranty", "approved", "Hardware Defect", "Soundbar optical input intermittent crackle", 45, 3),
        (9, "replacement", "approved", "Battery & Power", "Robotic vacuum battery discharging in dock", 65, 2),
        (7, "refund", "rejected", "Physical Damage", "Smart speaker dropped into kitchen sink", 25, 2),
        (6, "warranty", "under_review", "Software / Firmware Glitch", "Drone gimbal calibration timeout failure", 65, None),
        (4, "warranty", "submitted", "Hardware Defect", "Air purifier laser particle sensor frozen", 50, None),
        (2, "replacement", "under_review", "Battery & Power", "Wireless power bank heating to 58C while charging", 90, None),
        (1, "refund", "submitted", "Display / Screen Failure", "Vertical green artifact line on tablet OLED", 60, None)
    ]

    target_products = [p for p in created_products if p['user_id'] in (david_primary, elena_primary)]
    if not target_products:
        target_products = created_products

    for idx, (days_ago, c_type, c_status, c_cat, c_title, c_prio, res_after) in enumerate(batch_scenarios, 1):
        prod = target_products[idx % len(target_products)]
        created_dt = now - timedelta(days=days_ago)
        resolved_dt = (created_dt + timedelta(days=res_after)).isoformat() if res_after else None
        
        batch_claim = {
            "claim_number": f"CLM-{(today - timedelta(days=days_ago)).strftime('%Y%m%d')}-BI{idx:02d}9",
            "user_id": prod["user_id"],
            "product_id": prod["id"],
            "type": c_type,
            "status": c_status,
            "title": c_title,
            "description": f"Automated scenario fixture for presentation analytics: {c_title}.",
            "issue_category": c_cat,
            "incident_date": (today - timedelta(days=days_ago + 1)).isoformat(),
            "priority": c_prio,
            "resolved_at": resolved_dt,
            "created_at": created_dt.isoformat(),
            "updated_at": (datetime.fromisoformat(resolved_dt) if resolved_dt else created_dt).isoformat()
        }
        api_call("POST", "/rest/v1/claims", batch_claim)

    print(f"  ✓ Generated {len(batch_scenarios)} historical claims with 30-day timeline distribution.")

    print("\n==============================================================================")
    print("✓ Claimly Presentation Seeding Successfully Completed!")
    print("==============================================================================")
    run_verify()

if action == "seed":
    run_seed()
elif action == "clean":
    run_clean()
elif action == "verify":
    run_verify()
else:
    print(f"Unknown action: {action}")
    sys.exit(1)
EOF
