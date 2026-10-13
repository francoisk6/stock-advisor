"""Register -> onboarding -> home -> confirm email -> profile -> sign out/in -> delete account."""

import re

from playwright.sync_api import expect, sync_playwright

from helpers import (
    ARTIFACTS, BASE, button, delete_account, enable_semantics, fill, link_from_outbox, option,
    step, unique_email,
)

EMAIL = unique_email("signup")
PASSWORD = "E2eSecret123"

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": 1100, "height": 1000})
    try:
        page.goto(BASE + "/", wait_until="networkidle")
        enable_semantics(page)
        expect(button(page, "Sign in")).to_be_visible(timeout=15000)
        step("signed-out user lands on login")

        button(page, "Create an account").click()
        fill(page, "Your name", "Eve Tester")
        fill(page, "Email", EMAIL)
        fill(page, "Password", PASSWORD)
        button(page, "Create account").click()
        expect(page.get_by_text("How much do you know about investing?")).to_be_visible(
            timeout=15000
        )
        step("registration leads to onboarding")

        for choice in ["I'm new to this", "Wait and see", "In more than 5 years"]:
            option(page, choice).click()
            button(page, "Next").click()
        option(page, "Crypto").click()
        button(page, "Next").click()
        option(page, "Middle East").click()
        button(page, "Finish").click()
        expect(page.get_by_text("Hi, Eve")).to_be_visible(timeout=15000)
        expect(page.get_by_text(re.compile("Please confirm your email"))).to_be_visible()
        step("onboarding done -> home with greeting and confirm-email banner")

        page.goto(link_from_outbox(EMAIL, "verify-email"), wait_until="networkidle")
        enable_semantics(page)
        expect(page.get_by_text("Email confirmed!")).to_be_visible(timeout=15000)
        button(page, "Continue").click()
        expect(page.get_by_text("Hi, Eve")).to_be_visible(timeout=15000)
        expect(page.get_by_text(re.compile("Please confirm your email"))).to_have_count(0)
        step("email link confirms the address; session survives the reload")

        button(page, "Profile").click()
        expect(page.get_by_role("group", name=re.compile(
            "Your investing profile.*Beginner.*Balanced.*In more than 5 years.*Crypto.*Middle East"
        ))).to_be_visible(timeout=10000)
        button(page, "Back").click()
        expect(page.get_by_text("Hi, Eve")).to_be_visible(timeout=10000)
        step("profile shows quiz answers; back returns home")

        button(page, "Profile").click()
        button(page, "Sign out").click()
        expect(button(page, "Sign in")).to_be_visible(timeout=10000)
        fill(page, "Email", EMAIL)
        fill(page, "Password", "WrongPass999")
        button(page, "Sign in").click()
        expect(page.get_by_text("Invalid email or password")).to_be_visible(timeout=10000)
        fill(page, "Password", PASSWORD)
        button(page, "Sign in").click()
        expect(page.get_by_text("Hi, Eve")).to_be_visible(timeout=15000)
        step("sign out; wrong password is explained; sign in returns home")

        button(page, "Profile").click()
        button(page, "Delete account").click()
        fill(page, "Enter your password to confirm", PASSWORD)
        button(page, "Delete permanently").click()
        expect(button(page, "Sign in")).to_be_visible(timeout=10000)
        step("account deletion signs out")
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-signup-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:1500])
        delete_account(EMAIL, PASSWORD)
        raise
    finally:
        browser.close()
