"""Portfolio tracker: add a holding from an asset page, see value + risk overview, edit, remove."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, unique_email,
    wait_for_text,
)

EMAIL = unique_email("portfolio")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Pia Portfolio"})
token = tokens["access_token"]
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["stocks"], "region_interests": ["global"],
}, token=token, method="PUT")
aapl = next(a for a in api("/assets/search?q=AAPL", token=token, method="GET")
            if a["symbol"] == "AAPL")

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1400})
    try:
        page.goto(BASE + "/login", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_role("heading", name="Popular in your markets")).to_be_visible(
            timeout=15000
        )

        page.goto(f"{BASE}/assets/{aapl['id']}", wait_until="networkidle")
        enable_semantics(page)
        expect(page.get_by_role("heading", name="My portfolio")).to_be_visible(timeout=30000)
        button(page, "Add to my portfolio").click()
        wait_for_text(page, "Add AAPL to your portfolio")
        fill(page, "Units you own", "10")
        fill(page, "Average price paid (USD)", "150")
        button(page, "Save").click()
        wait_for_text(page, "Saved to your portfolio.")
        wait_for_text(page, r"You own 10 AAPL, worth \$[\d,]+\.\d\d")
        step("holding added from the asset page")

        page.goto(f"{BASE}/portfolio", wait_until="networkidle")
        enable_semantics(page)
        wait_for_text(page, r"Total value \$[\d,]+\.\d\d")
        wait_for_text(page, r"You have 1 holding\.")
        wait_for_text(page, r"10 AAPL · paid \$150\.00 on average")
        step("portfolio shows value, gain and a plain risk note")

        page.get_by_role("button", name=re.compile(r"^USD")).click()
        page.get_by_role("menuitem", name="SAR").click()
        wait_for_text(page, r"Total value SAR\s?[\d,]+\.\d\d")
        step("values shown in Saudi riyals")

        page.get_by_role("button", name=re.compile(r"^Apple Inc\.")).click()
        button(page, "Remove from portfolio").click()
        # The confirmation dialog's button comes after the sheet's.
        page.get_by_role("button", name="Remove from portfolio", exact=True).last.click()
        wait_for_text(page, "AAPL removed from your portfolio.")
        wait_for_text(page, "Add the stocks, funds or coins you own")
        step("holding removed")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-portfolio-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:3000])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
