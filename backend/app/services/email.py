import asyncio
import html
import logging
import smtplib
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import make_msgid
from pathlib import Path

from app.core.config import settings
from app.core.time import utcnow

logger = logging.getLogger(__name__)


@dataclass
class OutgoingEmail:
    to: str
    subject: str
    text: str
    html: str


# Filled only when EMAIL_BACKEND=memory (tests).
memory_outbox: list[OutgoingEmail] = []


def _build_message(email: OutgoingEmail) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = settings.email_from
    msg["To"] = email.to
    msg["Subject"] = email.subject
    msg["Message-ID"] = make_msgid()
    msg.set_content(email.text)
    msg.add_alternative(email.html, subtype="html")
    return msg


def _send_smtp(msg: EmailMessage) -> None:
    if settings.smtp_use_ssl:
        client: smtplib.SMTP = smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=30)
    else:
        client = smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=30)
    with client as smtp:
        if not settings.smtp_use_ssl and settings.smtp_starttls:
            smtp.starttls()
        if settings.smtp_user:
            smtp.login(settings.smtp_user, settings.smtp_password)
        smtp.send_message(msg)


def _write_outbox(msg: EmailMessage, to: str) -> Path:
    outbox = Path(settings.email_outbox_dir)
    outbox.mkdir(parents=True, exist_ok=True)
    safe_to = "".join(c if c.isalnum() else "_" for c in to)
    path = outbox / f"{utcnow():%Y%m%d-%H%M%S-%f}-{safe_to}.eml"
    path.write_bytes(bytes(msg))
    return path


async def send_email(email: OutgoingEmail) -> None:
    """Deliver an email via the configured backend. Never raises: failures are logged."""
    try:
        if settings.email_backend == "memory":
            memory_outbox.append(email)
            return
        msg = _build_message(email)
        if settings.email_backend == "smtp":
            await asyncio.to_thread(_send_smtp, msg)
        else:
            path = await asyncio.to_thread(_write_outbox, msg, email.to)
            logger.info("Email to %s written to %s", email.to, path)
    except Exception:
        logger.exception("Failed to send email to %s (%s)", email.to, email.subject)


def _layout(title: str, body_html: str) -> str:
    return f"""<!doctype html>
<html><body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:24px">
<div style="max-width:520px;margin:auto;background:#fff;border-radius:12px;padding:24px">
<h2 style="color:#1E6F5C;margin-top:0">{title}</h2>
{body_html}
<p style="color:#888;font-size:12px;margin-top:32px">
Stock Adviser — educational information only, not financial advice.</p>
</div></body></html>"""


def _button(url: str, label: str) -> str:
    return (
        f'<p><a href="{url}" style="background:#1E6F5C;color:#fff;padding:12px 20px;'
        f'border-radius:8px;text-decoration:none;display:inline-block">{label}</a></p>'
        f'<p style="font-size:12px;color:#666">Or copy this link: {url}</p>'
    )


def verification_email(to: str, name: str, url: str) -> OutgoingEmail:
    hours = settings.email_verify_token_hours
    greeting = f"Hi {name}," if name else "Hi,"
    greeting_html = html.escape(greeting)
    return OutgoingEmail(
        to=to,
        subject="Confirm your email — Stock Adviser",
        text=(
            f"{greeting}\n\nPlease confirm your email address by opening this link:\n{url}\n\n"
            f"The link expires in {hours} hours. If you didn't sign up, ignore this email."
        ),
        html=_layout(
            "Confirm your email",
            f"<p>{greeting_html}</p>"
            "<p>Please confirm your email address to secure your account.</p>"
            + _button(url, "Confirm email")
            + f"<p>The link expires in {hours} hours. "
            "If you didn't sign up, ignore this email.</p>",
        ),
    )


def password_reset_email(to: str, name: str, url: str) -> OutgoingEmail:
    minutes = settings.password_reset_token_minutes
    greeting = f"Hi {name}," if name else "Hi,"
    greeting_html = html.escape(greeting)
    return OutgoingEmail(
        to=to,
        subject="Reset your password — Stock Adviser",
        text=(
            f"{greeting}\n\nWe received a request to reset your password. "
            f"Open this link:\n{url}\n\n"
            f"The link expires in {minutes} minutes. If you didn't ask for this, ignore this email."
        ),
        html=_layout(
            "Reset your password",
            f"<p>{greeting_html}</p><p>We received a request to reset your password.</p>"
            + _button(url, "Choose a new password")
            + f"<p>The link expires in {minutes} minutes. "
            "If you didn't ask for this, you can safely ignore this email.</p>",
        ),
    )


def alert_email(to: str, name: str, title: str, body: str, url: str) -> OutgoingEmail:
    greeting = f"Hi {name}," if name else "Hi,"
    return OutgoingEmail(
        to=to,
        subject=f"Price alert: {title}",
        text=(
            f"{greeting}\n\n{body}\n\nSee the chart: {url}\n\n"
            "Educational information only — not financial advice."
        ),
        html=_layout(
            html.escape(title),
            f"<p>{html.escape(greeting)}</p><p>{html.escape(body)}</p>"
            + _button(url, "See the chart"),
        ),
    )
