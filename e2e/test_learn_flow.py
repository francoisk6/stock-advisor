"""Glossary (search, term page, related terms) and "Explain this" on an asset page."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, unique_email,
    wait_for_text,
)

EMAIL = unique_email("learn")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Lea Learn"})
token = tokens["access_token"]
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["stocks"], "region_interests": ["global"],
}, token=token, method="PUT")
aapl = next(a for a in api("/assets/search?q=AAPL", token=token, method="GET")
            if a["symbol"] == "AAPL")

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

        button(page, "Learn").click()
        wait_for_text(page, r"Beta How much a stock tends to move")
        page.get_by_role("textbox").click()
        page.wait_for_timeout(300)
        page.keyboard.type("dividend", delay=20)
        wait_for_text(page, "Yearly dividends as a percentage of the share price")
        step("glossary lists terms and search narrows them")

        page.get_by_role("button", name=re.compile(r"^Dividend yield")).click()
        wait_for_text(page, "A very high yield can be a warning sign")
        wait_for_text(page, "Related terms")
        button(page, "P/E ratio").click()
        wait_for_text(page, r"investors pay \$20 for every \$1")
        step("term page explains with an example; related terms link on")

        page.goto(f"{BASE}/assets/{aapl['id']}", wait_until="networkidle")
        enable_semantics(page)
        expect(page.get_by_role("heading", name="Key figures")).to_be_visible(timeout=30000)
        page.get_by_role("button", name=re.compile(r"^Market cap")).click()
        wait_for_text(page, "Ask the Copilot")
        button(page, "Learn more").click()
        wait_for_text(page, r"Market cap = share price × number of shares")
        step("key figure sheet links to the glossary entry")

        page.go_back()
        expect(page.get_by_role("heading", name="Key figures")).to_be_visible(timeout=30000)
        page.get_by_role("button", name=re.compile(r"^Change today")).click()
        wait_for_text(page, "previous trading day's closing price")
        button(page, "Got it").click()
        step("today's change explains itself")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-learn-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:2500])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
