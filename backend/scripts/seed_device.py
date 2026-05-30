"""
Seed script: register an ESP32 device in the database and print its pairing code.

Usage (from backend/ directory, with venv active):
    python scripts/seed_device.py --mac a0:b7:65:c1:d2:e3

The MAC address is printed on the ESP32 module label or shown via:
    Serial.println(WiFi.macAddress());  // in Arduino/PlatformIO

What this script does:
  1. Generates the pairing code: SHA-256(mac + PAIRING_SECRET)[:8].upper()
  2. Hashes it with bcrypt (for DB storage)
  3. Inserts (or skips if already exists) a row in the `devices` table
  4. Prints the pairing code — use it with POST /devices/{id}/claim
"""

import argparse
import asyncio
import re
import sys

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Allow running from backend/ directory
sys.path.insert(0, ".")

from app.config import settings
from app.db.models import Device
from app.devices.pairing import generate_pairing_code, hash_pairing_code

# ── helpers ──────────────────────────────────────────────────────────────────

_MAC_RE = re.compile(r"^([0-9a-fA-F]{2}[:\-]){5}[0-9a-fA-F]{2}$")


def mac_to_device_id(mac: str) -> str:
    """'a0:b7:65:c1:d2:e3'  →  'vena-a0b765c1d2e3'"""
    return "vena-" + mac.lower().replace(":", "").replace("-", "")


# ── main ─────────────────────────────────────────────────────────────────────


async def seed(mac: str) -> None:
    if not _MAC_RE.match(mac):
        print(f"ERROR: '{mac}' is not a valid MAC address (expected XX:XX:XX:XX:XX:XX)")
        sys.exit(1)

    device_id = mac_to_device_id(mac)
    pairing_code = generate_pairing_code(mac)
    pairing_hash = hash_pairing_code(pairing_code)

    engine = create_async_engine(settings.database_url, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        result = await session.execute(select(Device).where(Device.id == device_id))
        existing = result.scalar_one_or_none()

        if existing is not None:
            print(f"Device '{device_id}' already exists in DB — skipping insert.")
        else:
            device = Device(
                id=device_id,
                pairing_code_hash=pairing_hash,
                status="never_connected",
            )
            session.add(device)
            await session.commit()
            print(f"Device '{device_id}' inserted into DB.")

    await engine.dispose()

    print()
    print("=" * 40)
    print(f"  device_id   : {device_id}")
    print(f"  pairing code: {pairing_code}")
    print("=" * 40)
    print()
    print("Use the pairing code above with:")
    print(f"  POST /devices/{device_id}/claim")
    print(f"  body: {{ \"pairing_code\": \"{pairing_code}\" }}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Register an ESP32 device in the database.")
    parser.add_argument(
        "--mac",
        required=True,
        help="ESP32 MAC address (e.g. a0:b7:65:c1:d2:e3)",
    )
    args = parser.parse_args()
    asyncio.run(seed(args.mac))
