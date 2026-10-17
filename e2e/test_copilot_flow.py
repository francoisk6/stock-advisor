"""Copilot with the real local model: a price question and an app action (slow on CPU)."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, step, unique_email,
    wait_for_text,
)

EMAIL = unique_email("copilot")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Cora Pilot"})
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["stocks", "crypto"], "region_interests": ["middle_east"],
}, token=tokens["access_token"], method="PUT")

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1300})
    try:
        page.goto(BASE + "/login", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_role("button", name="Ask Copilot")).to_be_visible(timeout=15000)
        page.get_by_role("button", name="Ask Copilot").click()
        wait_for_text(page, "Hi Cora!")
        wait_for_text(page, "30 questions left today")
        step("copilot opens with starters and the daily allowance")

        page.get_by_role("button", name="How is Bitcoin doing this week?").click()
        # The answer must quote a dollar price taken from the tool, then finish.
        wait_for_text(page, r"\$\d[\d,]*", timeout=180)
        wait_for_text(page, "29 questions left today", timeout=180)
        step("answer streamed with a real price; allowance counted")

        fill(page, "Ask about a stock, coin or market…", "Add Saudi Aramco to my watchlist")
        page.keyboard.press("Enter")
        wait_for_text(page, r"Added Saudi Aramco \(Saudi Arabian Oil Company\) to your watchlist", timeout=180)
        wait_for_text(page, "28 questions left today", timeout=180)
        watchlist = api("/watchlist", token=tokens["access_token"], method="GET")
        assert [i["symbol"] for i in watchlist["items"]] == ["2222.SR"], watchlist["items"]
        step("app action: Aramco really added, with an action card")
        page.screenshot(path=f"{ARTIFACTS}/e2e-copilot.png", full_page=True)
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-copilot-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:3000])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
