"""Forgot password -> email link -> new password -> sign in."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, api, button, delete_account, enable_semantics, fill, link_from_outbox,
    step, unique_email,
)

EMAIL = unique_email("reset")
OLD_PASSWORD, NEW_PASSWORD = "E2eSecret123", "BrandNew456"

api("/auth/register", {"email": EMAIL, "password": OLD_PASSWORD, "full_name": "Rita Reset"})

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1000})
    try:
        page.goto(BASE + "/forgot-password", wait_until="networkidle")
        enable_semantics(page)
        fill(page, "Email", EMAIL)
        button(page, "Send reset link").click()
        expect(page.get_by_text(re.compile("If an account exists"))).to_be_visible(timeout=10000)
        step("forgot-password shows a neutral confirmation")

        page.goto(link_from_outbox(EMAIL, "reset-password"), wait_until="networkidle")
        enable_semantics(page)
        fill(page, "New password", NEW_PASSWORD)
        fill(page, "Confirm password", "Mismatch456")
        button(page, "Save new password").click()
        expect(page.get_by_text("The passwords don't match.")).to_be_visible(timeout=5000)
        fill(page, "Confirm password", NEW_PASSWORD)
        button(page, "Save new password").click()
        expect(page.get_by_text(re.compile("Your password was changed"))).to_be_visible(
            timeout=10000
        )
        step("reset link sets a new password (mismatch caught first)")

        button(page, "Sign in").click()
        fill(page, "Email", EMAIL)
        fill(page, "Password", NEW_PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_text("How much do you know about investing?")).to_be_visible(
            timeout=15000
        )
        step("new password signs in")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-reset-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:1500])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, NEW_PASSWORD)
        delete_account(EMAIL, OLD_PASSWORD)
