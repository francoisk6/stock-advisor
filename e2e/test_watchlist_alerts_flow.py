"""Star an asset -> it's on Home; create an alert -> live pop-up, bell badge, email."""

import email as email_lib
import email.policy
import glob
import os
import re
import time

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, OUTBOX, api, button, delete_account, enable_semantics, fill,
    link_from_outbox, step, unique_email, wait_for_text,
)

EMAIL = unique_email("alerts")
PASSWORD = "E2eSecret123"

tokens = api("/auth/register", {"email": EMAIL, "password": PASSWORD, "full_name": "Al Ert"})
token = link_from_outbox(EMAIL, "verify-email").split("token=")[1]
api("/auth/verify-email", {"token": token})  # confirmed -> alert emails allowed
api("/users/me/profile", {
    "experience_level": "beginner", "risk_profile": "balanced", "investment_horizon": "long",
    "asset_interests": ["crypto"], "region_interests": ["global"],
}, token=tokens["access_token"], method="PUT")


def alert_email_subjects() -> list[str]:
    safe_to = "".join(c if c.isalnum() else "_" for c in EMAIL)
    subjects = []
    for path in glob.glob(os.path.join(OUTBOX, f"*-{safe_to}.eml")):
        with open(path, "rb") as f:
            subjects.append(email_lib.message_from_binary_file(f, policy=email.policy.default)["Subject"])
    return [s for s in subjects if s.startswith("Price alert")]


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1400})
    try:
        page.goto(BASE + "/login", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        wait_for_text(page, "Tap ☆ on any stock")
        step("empty watchlist explains how to add assets")

        page.get_by_role("button", name=re.compile(r"^Bitcoin BTC")).first.click()
        wait_for_text(page, r"BTC · Crypto \$[\d,]+\.\d\d")  # name is its own heading
        button(page, "Add to watchlist").click()
        wait_for_text(page, "Added to your watchlist")
        # Regex: while the mouse hovers, the tooltip's text is added to the button's name.
        expect(
            page.get_by_role("button", name=re.compile("^Remove from watchlist"))
        ).to_be_visible()
        button(page, "Back").click()
        expect(page.get_by_role("heading", name="Your watchlist")).to_be_visible(timeout=15000)
        wait_for_text(page, r"Your watchlist.*Bitcoin|Bitcoin BTC")
        step("starred asset appears in the Home watchlist")

        page.get_by_role("button", name=re.compile(r"^Bitcoin BTC")).first.click()
        wait_for_text(page, "Price alerts")
        page.get_by_role("button", name="Create alert").click()
        wait_for_text(page, "Price goes above")
        fill(page, "Target price (USD)", "1")
        wait_for_text(page, r"Price goes above \$1\.00")
        page.get_by_role("button", name="Create alert").last.click()
        wait_for_text(page, "Alert created")
        step("alert created from the asset page")

        # Background check runs every 3 s in e2e; the result arrives over the live socket.
        wait_for_text(page, r"BTC is above \$1\.00", timeout=40)
        step("live pop-up when the alert fires")

        button(page, "Back").click()
        notifications = page.get_by_role("button", name=re.compile(r"^Notifications \(1 unread\)"))
        expect(notifications).to_be_visible(timeout=15000)
        notifications.click()
        wait_for_text(page, r"BTC is above \$1\.00")
        wait_for_text(page, "This alert is now switched off")
        step("bell shows 1 unread; notification is in the inbox")

        deadline = time.time() + 20
        while not alert_email_subjects() and time.time() < deadline:
            time.sleep(0.5)
        assert alert_email_subjects() == ["Price alert: BTC is above $1.00"], alert_email_subjects()
        step("alert email sent to the confirmed address")
        page.screenshot(path=f"{ARTIFACTS}/e2e-notifications.png", full_page=True)
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-alerts-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:2500])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
