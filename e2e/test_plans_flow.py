"""Plans: a full Free watchlist explains the limit, the Plans screen shows usage, Free vs Pro
and prices, and "tell me when Pro is ready" is recorded."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, unique_email,
    wait_for_text,
)

EMAIL = unique_email("plans")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Pam Plans"})
token = tokens["access_token"]
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["crypto"], "region_interests": ["global"],
}, token=token, method="PUT")
popular = api("/assets/popular", token=token, method="GET")
for asset in popular[:3]:  # the Free plan's 3 watchlist places
    api(f"/watchlist/assets/{asset['id']}", token=token, method="PUT")
fourth = popular[3]

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

        page.goto(f"{BASE}/assets/{fourth['id']}", wait_until="networkidle")
        enable_semantics(page)
        button(page, "Add to watchlist").click()
        wait_for_text(page, "You've reached a limit of your plan")
        wait_for_text(page, r"up to 3 assets in your watchlist.*Pro \(coming soon\)")
        page.get_by_role("button", name=re.compile(r"^See plans")).last.click()
        step("a 4th watchlist asset explains the Free limit")

        wait_for_text(page, "Your plan: Free")
        wait_for_text(page, r"Watchlist assets 3 of 3")
        wait_for_text(page, r"\$4\.99 a month, or \$39\.99 a year")
        step("plans screen shows usage, Free vs Pro and prices")

        button(page, "Tell me when Pro is ready").click()
        wait_for_text(page, "We'll let you know when Pro is ready")
        usage = api("/plans/usage", token=token, method="GET")
        assert usage["pro_interest_at"], usage
        step("interest in Pro is recorded")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-plans-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:3000])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
