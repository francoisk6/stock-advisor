"""Practice account: buy Bitcoin with practice dollars, see it in Practice, sell all, start over."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, tab, unique_email,
    wait_for_text,
)

EMAIL = unique_email("practice")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Pat Practice"})
token = tokens["access_token"]
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["crypto"], "region_interests": ["global"],
}, token=token, method="PUT")
btc = next(a for a in api("/assets/search?q=BTC", token=token, method="GET")
           if a["symbol"] == "BTC")

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1300})
    try:
        page.goto(BASE + "/login", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_role("heading", name="Popular in your markets")).to_be_visible(
            timeout=15000
        )

        tab(page, "Practice").click()
        wait_for_text(page, r"Total value \$10,000\.00")
        wait_for_text(page, "You haven't bought anything yet")
        step("practice account opens with $10,000")

        page.goto(f"{BASE}/assets/{btc['id']}", wait_until="networkidle")
        enable_semantics(page)
        expect(page.get_by_role("heading", name="Practice")).to_be_visible(timeout=30000)
        button(page, "Practice buy").click()
        wait_for_text(page, r"Price now: \$[\d,]+\.\d\d")
        fill(page, "Amount in US dollars", "500")
        wait_for_text(page, r"≈ 0\.\d+ BTC")
        button(page, "Buy with practice money").click()
        wait_for_text(page, r"Bought 0\.\d+ BTC for \$500\.00 \(practice\)")
        wait_for_text(page, r"You have 0\.\d+ BTC in your practice account, worth \$[\d,]+\.\d\d")
        step("practice buy of $500 of Bitcoin fills at the live price")

        page.goto(f"{BASE}/practice", wait_until="networkidle")
        enable_semantics(page)
        wait_for_text(page, r"Bitcoin")
        wait_for_text(page, r"Bought 0\.\d+ BTC")
        wait_for_text(page, r"Cash available \$9,500\.00")
        step("Practice screen shows the holding, cash and the trade")

        page.goto(f"{BASE}/assets/{btc['id']}", wait_until="networkidle")
        enable_semantics(page)
        button(page, "Practice sell").click()
        button(page, "Sell all").click()
        button(page, "Sell (practice)").click()
        wait_for_text(page, r"Sold 0\.\d+ BTC for \$[\d,]+\.\d\d \(practice\)")
        step("sell all closes the position")

        page.goto(f"{BASE}/practice", wait_until="networkidle")
        enable_semantics(page)
        wait_for_text(page, r"Locked in [+-]?\$\d")
        page.get_by_role("button", name=re.compile("Show menu")).click()
        page.get_by_role("menuitem", name="Start over").click()
        button(page, "Start over").click()
        wait_for_text(page, r"starts again with \$10,000\.00")
        wait_for_text(page, r"Total value \$10,000\.00")
        step("start over resets the account")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-practice-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:3000])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
