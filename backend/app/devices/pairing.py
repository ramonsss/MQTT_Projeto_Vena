import hashlib

import bcrypt

from app.config import settings


def generate_pairing_code(mac: str) -> str:
    """SHA-256(mac_lowercase_colon + PAIRING_SECRET)[:8].upper() — deterministic from MAC address.

    Example: generate_pairing_code("A0:B7:65:C1:D2:E3") -> same as ("a0:b7:65:c1:d2:e3")
    Normalizes MAC to lowercase colon-separated format before hashing,
    matching the algorithm in scripts/generate_qr.py.
    """
    clean = mac.lower().replace(":", "").replace("-", "")
    mac_norm = ":".join(clean[i:i + 2] for i in range(0, 12, 2))
    raw = mac_norm + settings.pairing_secret
    digest = hashlib.sha256(raw.encode()).hexdigest()
    return digest[:8].upper()


def hash_pairing_code(code: str) -> str:
    """bcrypt hash stored in devices.pairing_code_hash."""
    return bcrypt.hashpw(code.encode(), bcrypt.gensalt()).decode()


def verify_pairing_code(code: str, hashed: str) -> bool:
    """Returns True if the plaintext code matches the stored bcrypt hash."""
    return bcrypt.checkpw(code.encode(), hashed.encode())
