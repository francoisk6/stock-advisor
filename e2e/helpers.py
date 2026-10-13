"""Shared helpers for driving the Flutter web app through its accessibility tree."""

import email
import email.policy
import glob
import os
import re
import time
import urllib.request
import json

from playwright.sync_api import Page

BASE = os.environ.get("E2E_BASE_URL", "http://localhost:8210")
API = os.environ.get("E2E_API_URL", "http://localhost:8200/api/v1")
OUTBOX = os.environ["E2E_OUTBOX"]
ARTIFACTS = os.environ.get("E2E_ARTIFACTS", "/tmp")


def step(text: str) -> None:
    print("✓", text, flush=True)


def unique_email(prefix: str) -> str:
    return f"e2e-{prefix}-{int(time.time() * 1000)}@example.com"


def enable_semantics(page: Page) -> None:
    """Flutter renders to a canvas; turning on semantics exposes buttons and fields."""
    page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=30000)
    page.locator("flt-semantics-placeholder").dispatch_event("click")
    page.wait_for_selector("flt-semantics", state="attached", timeout=10000)


def fill(page: Page, label: str, value: str) -> None:
    """Type like a user; Playwright's fill() is not reliably seen by Flutter text fields."""
    field = page.get_by_label(label, exact=True)
    field.wait_for(state="visible", timeout=15000)
    page.wait_for_timeout(400)  # let page transitions finish before focusing
    field.click()
    page.wait_for_timeout(200)
    page.keyboard.press("Control+A")
    page.keyboard.type(value, delay=10)
    page.wait_for_timeout(200)


def button(page: Page, name: str):
    return page.get_by_role("button", name=name, exact=True)


def option(page: Page, title: str):
    """Quiz options expose "<title> <description>" as one button label."""
    return page.get_by_role("button", name=re.compile("^" + re.escape(title)))


def link_from_outbox(to: str, kind: str) -> str:
    """Newest /<kind>?token=... link emailed to `to` (dev outbox backend)."""
    safe_to = "".join(c if c.isalnum() else "_" for c in to)
    for _ in range(20):
        for path in sorted(glob.glob(os.path.join(OUTBOX, f"*-{safe_to}.eml")), reverse=True):
            with open(path, "rb") as f:
                msg = email.message_from_binary_file(f, policy=email.policy.default)
            body = msg.get_body(preferencelist=("plain",)).get_content()
            match = re.search(rf"(http\S+/{kind}\?token=\S+)", body)
            if match:
                return match.group(1)
        time.sleep(0.5)
    raise AssertionError(f"no {kind} email for {to} in {OUTBOX}")


def api(path: str, body: dict | None = None, token: str | None = None, method: str = "POST"):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req) as response:
        raw = response.read()
        return json.loads(raw) if raw else None


def delete_account(email_addr: str, password: str) -> None:
    """Best-effort cleanup so the dev database doesn't collect test users."""
    try:
        token = api("/auth/login", {"email": email_addr, "password": password})["access_token"]
        api("/users/me", {"password": password}, token=token, method="DELETE")
    except Exception:
        pass
