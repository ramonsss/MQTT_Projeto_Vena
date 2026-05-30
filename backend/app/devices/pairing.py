import hashlib

import bcrypt

from app.config import settings


def generate_pairing_code(mac: str) -> str:
    """SHA-256(mac + PAIRING_SECRET)[:8].upper() — deterministic from MAC address.

    Example: generate_pairing_code("a0:b7:65:c1:d2:e3") -> "K7X9M2P4"
    Used at factory time to produce the code printed on device label / QR.
    """
    raw = mac + settings.pairing_secret
    digest = hashlib.sha256(raw.encode()).hexdigest()
    return digest[:8].upper()


def hash_pairing_code(code: str) -> str:
    """bcrypt hash stored in devices.pairing_code_hash."""
    return bcrypt.hashpw(code.encode(), bcrypt.gensalt()).decode()


def verify_pairing_code(code: str, hashed: str) -> bool:
    """Returns True if the plaintext code matches the stored bcrypt hash."""
    return bcrypt.checkpw(code.encode(), hashed.encode())
