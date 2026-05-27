"""
Generate a Vena QR code from an ESP32 MAC address.

Uses the same deterministic algorithm as the firmware (main.cpp → buildDeviceId).

Usage:
    python scripts/generate_qr.py D0:EF:76:32:35:F4
    python scripts/generate_qr.py D0:EF:76:32:35:F4 --output vena_qr.png

Requirements:
    pip install qrcode[pil]
"""

import argparse
import json
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


def mac_to_pairing_code(mac: str) -> str:
    """Mesmo XOR do firmware: mac[0]^0x5A, mac[1]^0xA5, mac[2]^0x3C, mac[3]^0xC3."""
    clean = mac.replace(":", "").replace("-", "")
    octets = [int(clean[i : i + 2], 16) for i in range(0, 12, 2)]
    xor_keys = [0x5A, 0xA5, 0x3C, 0xC3]
    code_bytes = [octets[i] ^ xor_keys[i] for i in range(4)]
    return f"{code_bytes[0]:02X}{code_bytes[1]:02X}-{code_bytes[2]:02X}{code_bytes[3]:02X}"


def mac_to_ble_name(mac: str) -> str:
    """Vena- + últimos 4 hex do MAC (uppercase)."""
    clean = mac.replace(":", "").replace("-", "").upper()
    return f"Vena-{clean[-4:]}"


def main():
    parser = argparse.ArgumentParser(description="Gera QR code para provisioning Vena")
    parser.add_argument("mac", help="MAC do ESP32 (ex: D0:EF:76:32:35:F4)")
    parser.add_argument("-o", "--output", default="vena_qr.png", help="Arquivo PNG de saída")
    parser.add_argument("--show", action="store_true", help="Abrir imagem após gerar")
    args = parser.parse_args()

    device_id = mac_to_device_id(args.mac)
    pairing_code = mac_to_pairing_code(args.mac)
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
