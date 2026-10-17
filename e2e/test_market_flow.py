"""Home "popular" list -> search -> asset page (chart ranges, candles, key figures), live data."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, unique_email,
    wait_for_no_text, wait_for_text,
)

EMAIL = unique_email("market")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Mo Market"})
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["stocks", "crypto"], "region_interests": ["middle_east"],
}, token=tokens["access_token"], method="PUT")

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1200})
    try:
        page.goto(BASE + "/login", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_role("heading", name="Popular in your markets")).to_be_visible(
            timeout=15000
        )
        wait_for_text(page, r"Saudi Aramco \(Saudi Arabian Oil Company\) .*SAR\u00a0?\s?\d+\.\d\d [+-]?\d+\.\d\d%")
        wait_for_text(page, r"Bitcoin BTC · Crypto \$[\d,]+\.\d\d")
        step("home lists Middle East stocks + crypto with live prices")

        page.get_by_role("checkbox", name="Crypto").click()
        wait_for_no_text(page, "Saudi Aramco")
        wait_for_text(page, "Bitcoin")
        step("interest filter narrows the list")

        page.get_by_role("searchbox").click()
        page.wait_for_timeout(800)
        page.keyboard.type("nvidia", delay=30)
        nvda = page.get_by_role("button", name=re.compile(r"^NVIDIA Corporation NVDA ·"))
        expect(nvda.first).to_be_visible(timeout=30000)
        nvda.first.click()
        expect(page.get_by_role("heading", name="Key figures")).to_be_visible(timeout=30000)
        wait_for_text(page, "over the past month")
        step("search -> asset page with chart and key figures")

        page.get_by_role("button", name=re.compile(r"^P\/E ratio")).click()
        wait_for_text(page, "how many years of", timeout=5)
        button(page, "Got it").click()
        step("key figure explains itself")

        page.get_by_role("checkbox", name="1Y").click()
        wait_for_text(page, "over the past year")
        page.get_by_role("button", name="Candles").click()
        wait_for_text(page, "Each candle shows one period")
        page.screenshot(path=f"{ARTIFACTS}/e2e-asset.png", full_page=True)
        step("1Y range and candle view work")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-market-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:2500])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
