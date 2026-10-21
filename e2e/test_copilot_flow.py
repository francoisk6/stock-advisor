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
        wait_for_text(page, "5 questions left today")
        step("copilot opens with starters and the daily allowance")

        page.get_by_role("button", name="How is Bitcoin doing this week?").click()
        # The answer must quote a dollar price taken from the tool, then finish.
        wait_for_text(page, r"\$\d[\d,]*", timeout=180)
        wait_for_text(page, "4 questions left today", timeout=180)
        step("answer streamed with a real price; allowance counted")

        fill(page, "Ask about a stock, coin or market…", "Add Saudi Aramco to my watchlist")
        page.keyboard.press("Enter")
        wait_for_text(page, r"Added Saudi Aramco \(Saudi Arabian Oil Company\) to your watchlist", timeout=180)
        wait_for_text(page, "3 questions left today", timeout=180)
        watchlist = api("/watchlist", token=tokens["access_token"], method="GET")
        assert [i["symbol"] for i in watchlist["items"]] == ["2222.SR"], watchlist["items"]
        step("app action: Aramco really added, with an action card")

        fill(page, "Ask about a stock, coin or market…", "Why did Bitcoin move today?")
        page.keyboard.press("Enter")
        wait_for_text(page, "2 questions left today", timeout=240)
        snapshot = page.locator("body").aria_snapshot()
        assert "](n" not in snapshot and "](w" not in snapshot, "unresolved citation shown"
        convo = api("/chat/conversations", token=tokens["access_token"], method="GET")[0]
        detail = api(f"/chat/conversations/{convo['id']}", token=tokens["access_token"],
                     method="GET")
        answer = detail["messages"][-1]["content"]
        print("     answer:", " ".join(answer.split())[:500])
        assert re.search(r"\]\(https?://", answer), "expected at least one cited source link"
        assert not re.search(r"don'?t have|can'?t provide|unable to", answer, re.I), (
            "answer claims to have no data although news was fetched"
        )
        # Typed-in URLs are stripped by the backend; what remains are fetched sources.
        links = re.findall(r"\]\((https?://[^)]+)\)", answer)
        assert not any("coingecko.com" in link for link in links), links
        step("news question answered with cited source links")

        button(page, "Back").click()
        expect(page.get_by_role("heading", name="Your 2-minute morning brief")).to_be_visible(
            timeout=15000
        )
        button(page, "Get today's brief now").click()
        expect(button(page, "Read")).to_be_visible(timeout=300000)
        button(page, "Read").click()
        wait_for_text(page, "Your markets", timeout=30)
        wait_for_text(page, "Saudi Aramco", timeout=10)  # from the watchlist
        wait_for_text(page, "Written by AI", timeout=10)
        brief = api("/digest/today", token=tokens["access_token"], method="GET")
        print("     brief:", " ".join(brief["content"].split())[:300])
        assert "## Your markets" in brief["content"]
        step("morning brief written on demand from the watchlist")

        movers = [
            a for kind in ("crypto", "stock", "commodity")
            for a in api(f"/assets/popular?type={kind}", token=tokens["access_token"],
                         method="GET")
            if a["quote"] and a["quote"]["change_percent"] is not None
            and abs(a["quote"]["change_percent"]) >= 2
        ]
        if not movers:
            step("no asset moved 2%+ today: 'why did it move?' not shown (nothing to check)")
        else:
            mover = movers[0]
            page.goto(f"{BASE}/assets/{mover['id']}", wait_until="networkidle")
            enable_semantics(page)
            wait_for_text(page, rf"Why is {re.escape(mover['symbol'])} (up|down)", timeout=60)
            button(page, "Explain").click()
            wait_for_text(page, "AI summary of recent headlines", timeout=300)
            step(f"'why did it move?' explained {mover['symbol']} "
                 f"({mover['quote']['change_percent']:+.1f}%)")
        page.screenshot(path=f"{ARTIFACTS}/e2e-copilot.png", full_page=True)
    except Exception:
        page.screenshot(path=f"{ARTIFACTS}/e2e-copilot-failure.png", full_page=True)
        print("FAILED at", page.url)
        print(page.locator("body").aria_snapshot()[:3000])
        raise
    finally:
        browser.close()
        delete_account(EMAIL, PASSWORD)
