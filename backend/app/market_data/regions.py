"""Where a Yahoo symbol trades: exchange display names and region/country by symbol suffix."""

# Yahoo symbol suffix -> (ISO country, region code used in user profiles)
SUFFIX_REGION: dict[str, tuple[str, str]] = {
    "SR": ("SA", "middle_east"),
    "AE": ("AE", "middle_east"),
    "AD": ("AE", "middle_east"),
    "QA": ("QA", "middle_east"),
    "KW": ("KW", "middle_east"),
    "BH": ("BH", "middle_east"),
    "OM": ("OM", "middle_east"),
    "TA": ("IL", "middle_east"),
    "IS": ("TR", "europe"),
    "CA": ("EG", "africa"),
    "JO": ("ZA", "africa"),
    "L": ("GB", "europe"),
    "IL": ("GB", "europe"),
    "DE": ("DE", "europe"),
    "F": ("DE", "europe"),
    "PA": ("FR", "europe"),
    "AS": ("NL", "europe"),
    "BR": ("BE", "europe"),
    "MI": ("IT", "europe"),
    "MC": ("ES", "europe"),
    "SW": ("CH", "europe"),
    "CO": ("DK", "europe"),
    "ST": ("SE", "europe"),
    "OL": ("NO", "europe"),
    "HE": ("FI", "europe"),
    "VI": ("AT", "europe"),
    "LS": ("PT", "europe"),
    "IR": ("IE", "europe"),
    "WA": ("PL", "europe"),
    "T": ("JP", "asia_pacific"),
    "HK": ("HK", "asia_pacific"),
    "SS": ("CN", "asia_pacific"),
    "SZ": ("CN", "asia_pacific"),
    "KS": ("KR", "asia_pacific"),
    "KQ": ("KR", "asia_pacific"),
    "TW": ("TW", "asia_pacific"),
    "NS": ("IN", "asia_pacific"),
    "BO": ("IN", "asia_pacific"),
    "SI": ("SG", "asia_pacific"),
    "AX": ("AU", "asia_pacific"),
    "NZ": ("NZ", "asia_pacific"),
    "JK": ("ID", "asia_pacific"),
    "KL": ("MY", "asia_pacific"),
    "BK": ("TH", "asia_pacific"),
    "TO": ("CA", "north_america"),
    "V": ("CA", "north_america"),
    "NE": ("CA", "north_america"),
    "MX": ("MX", "latin_america"),
    "SA": ("BR", "latin_america"),
    "BA": ("AR", "latin_america"),
    "SN": ("CL", "latin_america"),
}

# Yahoo exchange codes -> names beginners recognize.
EXCHANGE_NAMES: dict[str, str] = {
    "NMS": "NASDAQ",
    "NGM": "NASDAQ",
    "NCM": "NASDAQ",
    "NAS": "NASDAQ",
    "NYQ": "NYSE",
    "PCX": "NYSE Arca",
    "ASE": "NYSE American",
    "BTS": "Cboe",
    "PNK": "OTC",
    "SAU": "Tadawul",
    "DFM": "Dubai Financial Market",
    "ABU": "Abu Dhabi Securities Exchange",
    "DOH": "Qatar Stock Exchange",
    "CAI": "Egyptian Exchange",
    "JNB": "Johannesburg Stock Exchange",
    "LSE": "London Stock Exchange",
    "GER": "XETRA",
    "FRA": "Frankfurt",
    "PAR": "Euronext Paris",
    "AMS": "Euronext Amsterdam",
    "EBS": "SIX Swiss Exchange",
    "CPH": "Nasdaq Copenhagen",
    "JPX": "Tokyo Stock Exchange",
    "TYO": "Tokyo Stock Exchange",
    "HKG": "Hong Kong Stock Exchange",
    "KSC": "Korea Exchange",
    "NSI": "National Stock Exchange of India",
    "BSE": "Bombay Stock Exchange",
    "ASX": "ASX",
    "TOR": "Toronto Stock Exchange",
    "SAO": "B3 (Brazil)",
    "CCY": "Currency market",
    "CMX": "COMEX",
    "NYM": "NYMEX",
    "SNP": "S&P Indices",
    "DJI": "Dow Jones Indices",
    "NIM": "Nasdaq Indices",
}


def yahoo_location(symbol: str, quote_type: str) -> tuple[str | None, str]:
    """(country, region) for a Yahoo symbol."""
    if quote_type in ("CURRENCY", "FUTURE"):
        return None, "global"
    base = symbol.lstrip("^")
    if "." in base:
        suffix = base.rsplit(".", 1)[1].upper()
        if suffix in SUFFIX_REGION:
            return SUFFIX_REGION[suffix]
    return "US", "north_america"


def exchange_name(code: str | None, fallback: str | None = None) -> str | None:
    if code and code in EXCHANGE_NAMES:
        return EXCHANGE_NAMES[code]
    return fallback or code
