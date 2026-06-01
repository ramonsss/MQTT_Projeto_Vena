"""
Generate a Vena QR code from an ESP32 MAC address.

Uses the same deterministic algorithm as the firmware (main.cpp → buildDeviceId)
and the backend (pairing.py → generate_pairing_code).

Usage:
    python scripts/generate_qr.py D0:EF:76:32:35:F4
    python scripts/generate_qr.py D0:EF:76:32:35:F4 --output vena_qr.png

    The PAIRING_SECRET must match the backend .env.
    Set via env var or --secret argument:
        $env:PAIRING_SECRET="c23c03..."
        python scripts/generate_qr.py D0:EF:76:32:35:F4

Requirements:
    pip install qrcode[pil]
"""

import argparse
import hashlib
import json
import os
import sys

try:
    import qrcode
except ImportError:
    print("Instale o pacote: pip install qrcode[pil]")
    sys.exit(1)


def mac_to_device_id(mac: str) -> str:
    """vena- + MAC hex lowercase sem separadores."""
    clean = mac.replace(":", "").replace("-", "").lower()
    if len(clean) != 12:
        raise ValueError(f"MAC inválido: {mac}")
    return f"vena-{clean}"


def mac_to_pairing_code(mac: str, secret: str) -> str:
    """SHA-256(mac_lowercase_with_colons + secret)[:8].upper() — mirrors backend pairing.py."""
    mac_norm = mac.lower()
    # ensure colon-separated format (aa:bb:cc:dd:ee:ff)
    clean = mac_norm.replace(":", "").replace("-", "")
    mac_norm = ":".join(clean[i:i+2] for i in range(0, 12, 2))
    raw = mac_norm + secret
    return hashlib.sha256(raw.encode()).hexdigest()[:8].upper()


def mac_to_ble_name(mac: str) -> str:
    """Vena- + últimos 4 hex do MAC (uppercase)."""
    clean = mac.replace(":", "").replace("-", "").upper()
    return f"Vena-{clean[-4:]}"


def main():
    parser = argparse.ArgumentParser(description="Gera QR code para provisioning Vena")
    parser.add_argument("mac", help="MAC do ESP32 (ex: D0:EF:76:32:35:F4)")
    parser.add_argument("-o", "--output", default="vena_qr.png", help="Arquivo PNG de saída")
    parser.add_argument("--secret", default=os.environ.get("PAIRING_SECRET", ""),
                        help="PAIRING_SECRET do backend (ou defina via env var PAIRING_SECRET)")
    parser.add_argument("--show", action="store_true", help="Abrir imagem após gerar")
    args = parser.parse_args()

    if not args.secret:
        print("Erro: PAIRING_SECRET não informado. Use --secret ou defina a env var PAIRING_SECRET.")
        sys.exit(1)

    device_id = mac_to_device_id(args.mac)
    pairing_code = mac_to_pairing_code(args.mac, args.secret)
    ble_name = mac_to_ble_name(args.mac)

    payload = json.dumps(
        {"device_id": device_id, "pairing_code": pairing_code},
        separators=(",", ":"),
    )

    print(f"  MAC          : {args.mac}")
    print(f"  device_id    : {device_id}")
    print(f"  pairing_code : {pairing_code}")
    print(f"  BLE name     : {ble_name}")
    print(f"  QR payload   : {payload}")
    print()

    img = qrcode.make(payload, box_size=10, border=4)
    img.save(args.output)
    print(f"  ✓ QR salvo em: {args.output}")

    if args.show:
        img.show()


if __name__ == "__main__":
    main()
