import smtplib
from email.message import EmailMessage

import pytest

from app.core.config import settings
from app.services import email as email_service


class FakeSMTP:
    instances: list["FakeSMTP"] = []

    def __init__(self, host: str, port: int, timeout: int) -> None:
        self.host, self.port = host, port
        self.calls: list[str] = []
        FakeSMTP.instances.append(self)

    def __enter__(self) -> "FakeSMTP":
        return self

    def __exit__(self, *exc: object) -> None:
        self.calls.append("quit")

    def starttls(self) -> None:
        self.calls.append("starttls")

    def login(self, user: str, password: str) -> None:
        self.calls.append(f"login:{user}")

    def send_message(self, msg: EmailMessage) -> None:
        self.calls.append(f"send:{msg['To']}")


class FakeSMTPSSL(FakeSMTP):
    pass


@pytest.fixture
def fake_smtp(monkeypatch: pytest.MonkeyPatch) -> None:
    FakeSMTP.instances = []
    monkeypatch.setattr(smtplib, "SMTP", FakeSMTP)
    monkeypatch.setattr(smtplib, "SMTP_SSL", FakeSMTPSSL)
    monkeypatch.setattr(settings, "smtp_host", "smtp.example.com")
    monkeypatch.setattr(settings, "smtp_user", "bot@example.com")
    monkeypatch.setattr(settings, "smtp_starttls", True)
    monkeypatch.setattr(settings, "smtp_ssl", None)


def _message() -> EmailMessage:
    return email_service._build_message(
        email_service.verification_email("ana@example.com", "Ana", "http://x/verify-email?token=t")
    )


@pytest.mark.usefixtures("fake_smtp")
def test_port_465_uses_implicit_ssl(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "smtp_port", 465)
    email_service._send_smtp(_message())

    (client,) = FakeSMTP.instances
    assert isinstance(client, FakeSMTPSSL)
    assert client.calls == ["login:bot@example.com", "send:ana@example.com", "quit"]


@pytest.mark.usefixtures("fake_smtp")
def test_port_587_upgrades_with_starttls(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "smtp_port", 587)
    email_service._send_smtp(_message())

    (client,) = FakeSMTP.instances
    assert not isinstance(client, FakeSMTPSSL)
    assert client.calls == ["starttls", "login:bot@example.com", "send:ana@example.com", "quit"]


@pytest.mark.usefixtures("fake_smtp")
def test_explicit_ssl_flag_overrides_port(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "smtp_port", 2465)
    monkeypatch.setattr(settings, "smtp_ssl", True)
    email_service._send_smtp(_message())

    (client,) = FakeSMTP.instances
    assert isinstance(client, FakeSMTPSSL)
    assert "starttls" not in client.calls


def test_verification_email_escapes_name_in_html() -> None:
    mail = email_service.verification_email("a@example.com", "<b>Eve</b>", "http://x")
    assert "<b>Eve</b>" not in mail.html
    assert "&lt;b&gt;Eve&lt;/b&gt;" in mail.html
