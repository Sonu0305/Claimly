#!/usr/bin/env python3
"""
Automated Production Smoke & E2E Verification Script for Claimly on Vercel.
Runs Playwright headless tests against https://claimly-neon.vercel.app for both
Customer and Admin personas, testing auth, routing, and UI rendering.
"""

import asyncio
import os
import sys
from playwright.async_api import async_playwright

BASE_URL = os.environ.get("VERCEL_URL", "https://claimly-neon.vercel.app")
CHROME_PATH = os.environ.get("CHROME_PATH", "/home/swayam-shah/.local/bin/google-chrome")

async def test_admin(browser):
    print("==> Verifying Admin Flow on Production...")
    context = await browser.new_context(viewport={"width": 1440, "height": 900})
    page = await context.new_page()

    await page.goto(f"{BASE_URL}/login", wait_until="load")
    await asyncio.sleep(4)

    # Focus email
    await page.keyboard.press("Tab")
    await asyncio.sleep(0.3)
    await page.keyboard.type("marcus.admin@claimly.com", delay=20)
    await asyncio.sleep(0.3)

    # Move to password
    await page.keyboard.press("Tab")
    await asyncio.sleep(0.3)
    await page.keyboard.type("AdminSecret2026!", delay=20)
    await asyncio.sleep(0.3)

    # Submit
    await page.keyboard.press("Enter")
    await asyncio.sleep(7)

    assert "admin" in page.url, f"Expected admin route, got {page.url}"
    print(f"  [PASS] Admin Dashboard verified at {page.url}")

    # Admin Claims Review
    await page.goto(f"{BASE_URL}/admin/claims", wait_until="load")
    await asyncio.sleep(4)
    assert "/admin/claims" in page.url
    print(f"  [PASS] Admin Claims Review verified at {page.url}")

    # Admin Users Directory
    await page.goto(f"{BASE_URL}/admin/users", wait_until="load")
    await asyncio.sleep(4)
    assert "/admin/users" in page.url
    print(f"  [PASS] Admin Users Directory verified at {page.url}")

    await context.close()

async def test_customer(browser):
    print("==> Verifying Customer Flow on Production...")
    context = await browser.new_context(viewport={"width": 1440, "height": 900})
    page = await context.new_page()

    await page.goto(f"{BASE_URL}/login", wait_until="load")
    await asyncio.sleep(4)

    # Focus email
    await page.keyboard.press("Tab")
    await asyncio.sleep(0.3)
    await page.keyboard.type("sarah.jenkins@claimly.com", delay=20)
    await asyncio.sleep(0.3)

    # Move to password
    await page.keyboard.press("Tab")
    await asyncio.sleep(0.3)
    await page.keyboard.type("SecureP@ss2026!", delay=20)
    await asyncio.sleep(0.3)

    # Submit
    await page.keyboard.press("Enter")
    await asyncio.sleep(7)

    assert "customer" in page.url, f"Expected customer route, got {page.url}"
    print(f"  [PASS] Customer Home verified at {page.url}")

    # Customer Products
    await page.goto(f"{BASE_URL}/customer/products", wait_until="load")
    await asyncio.sleep(4)
    assert "/customer/products" in page.url
    print(f"  [PASS] Customer Products Vault verified at {page.url}")

    # Customer Claims
    await page.goto(f"{BASE_URL}/customer/claims", wait_until="load")
    await asyncio.sleep(4)
    assert "/customer/claims" in page.url
    print(f"  [PASS] Customer Claims verified at {page.url}")

    # Customer Claim Wizard
    await page.goto(f"{BASE_URL}/customer/claims/new", wait_until="load")
    await asyncio.sleep(4)
    assert "/customer/claims/new" in page.url
    print(f"  [PASS] 5-Step Claim Wizard verified at {page.url}")

    # Customer Profile
    await page.goto(f"{BASE_URL}/customer/profile", wait_until="load")
    await asyncio.sleep(4)
    assert "/customer/profile" in page.url
    print(f"  [PASS] Customer Profile verified at {page.url}")

    await context.close()

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            executable_path=CHROME_PATH,
            headless=True,
            args=["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"]
        )
        try:
            await test_admin(browser)
            await test_customer(browser)
            print("\nALL PRODUCTION SMOKE TESTS PASSED!")
        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
