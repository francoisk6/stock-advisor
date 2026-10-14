"""Plain-text money formatting for emails and notifications (mirrors the app's rules)."""

from decimal import Decimal

_SYMBOLS = {"USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "INR": "₹"}


def format_money(value: float | Decimal, currency: str | None) -> str:
    amount = float(value)
    digits = 2 if abs(amount) >= 1 else 4 if abs(amount) >= 0.01 else 6
    number = f"{amount:,.{digits}f}"
    if not currency:
        return number
    symbol = _SYMBOLS.get(currency)
    return f"{symbol}{number}" if symbol else f"{currency} {number}"


def format_percent(value: float | Decimal, signed: bool = True) -> str:
    number = float(value)
    sign = "+" if signed and number > 0 else ""
    return f"{sign}{number:.2f}%"
