from datetime import datetime, timezone


def utcnow() -> datetime:
    """Naive UTC datetime at second precision, matching MySQL DATETIME columns.

    Truncating keeps in-memory values identical to what is read back from the database.
    """
    return datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)
