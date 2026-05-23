"""
Flash a device JWT into the ESP32's NVS (Non-Volatile Storage) over USB.

Requirements:
    pip install esptool

Usage (from backend/ directory, with venv active):

  # Modo 1 — JWT já obtido manualmente:
  python scripts/provision_nvs.py --port COM3 --jwt "eyJhbGci..."

  # Modo 2 — busca o JWT automaticamente do backend:
  python scripts/provision_nvs.py --port COM3 \\
      --device-id vena-a0b765c1d2e3 \\
      --access-token "eyJhbGci..."

How it works:
  1. Cria um CSV temporário com o JWT no namespace "vena", chave "device_jwt"
  2. Converte para binário usando nvs_partition_gen.py (ESP-IDF / PlatformIO)
  3. Grava o binário na partição NVS do ESP32 (endereço padrão 0x9000)

O firmware lê o JWT no boot com Preferences.getString("device_jwt") e o usa
como username no MQTT connect.
"""

import argparse
import csv
import json
import os
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

NVS_PARTITION_ADDR = "0x9000"  # endereço padrão da partição NVS no ESP32
NVS_PARTITION_SIZE = "0x5000"  # 20 KB
NVS_NAMESPACE = "vena"
NVS_KEY = "device_jwt"


# ---------------------------------------------------------------------------
# Localizar nvs_partition_gen.py
# ---------------------------------------------------------------------------

def find_nvs_partition_gen() -> Path | None:
    """Procura nvs_partition_gen.py em locais comuns do ESP-IDF / PlatformIO."""
    candidates: list[str] = []

    # ESP-IDF via variável de ambiente
    idf_path = os.environ.get("IDF_PATH", "")
    if idf_path:
        candidates.append(
            f"{idf_path}/components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py"
        )

    # PlatformIO — caminhos comuns no Windows e Linux/macOS
    pio_home = Path.home() / ".platformio" / "packages"
    if pio_home.exists():
        for match in pio_home.glob("**/nvs_partition_gen.py"):
            candidates.append(str(match))

    for c in candidates:
        if c and Path(c).exists():
            return Path(c)
    return None


# ---------------------------------------------------------------------------
# Gerar binário NVS
# ---------------------------------------------------------------------------

def generate_nvs_binary(jwt: str, output_path: Path) -> None:
    """Cria o binário da partição NVS com o JWT no namespace vena:device_jwt."""
    nvs_gen = find_nvs_partition_gen()
    if nvs_gen is None:
        print(
            "ERRO: nvs_partition_gen.py não encontrado.\n"
            "Opções:\n"
            "  1. Instale o ESP-IDF e defina a variável IDF_PATH\n"
            "  2. O PlatformIO inclui o script — verifique ~/.platformio/packages/\n"
            "  3. Baixe diretamente:\n"
            "     https://github.com/espressif/esp-idf/blob/master/"
            "components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py"
        )
        sys.exit(1)

    # CSV temporário
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".csv", delete=False, newline=""
    ) as f:
        csv_path = f.name
        writer = csv.writer(f)
        writer.writerow(["key", "type", "encoding", "value"])
        writer.writerow([NVS_NAMESPACE, "namespace", "", ""])
        writer.writerow([NVS_KEY, "data", "string", jwt])

    try:
        result = subprocess.run(
            [
                sys.executable,
                str(nvs_gen),
                "generate",
                csv_path,
                str(output_path),
                NVS_PARTITION_SIZE,
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print("ERRO ao gerar binário NVS:")
            print(result.stderr or result.stdout)
            sys.exit(1)
    finally:
        Path(csv_path).unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Gravar no ESP32
# ---------------------------------------------------------------------------

def flash_nvs(port: str, binary_path: Path) -> None:
    """Grava o binário NVS no ESP32 via esptool."""
    try:
        import esptool  # noqa: F401
    except ImportError:
        print("ERRO: esptool não instalado.\nExecute: pip install esptool")
        sys.exit(1)

    subprocess.run(
        [
            sys.executable,
            "-m",
            "esptool",
            "--port",
            port,
            "--baud",
            "460800",
            "write_flash",
            NVS_PARTITION_ADDR,
            str(binary_path),
        ],
        check=True,
    )


# ---------------------------------------------------------------------------
# Buscar JWT automaticamente do backend
# ---------------------------------------------------------------------------

def fetch_device_jwt(device_id: str, access_token: str, base_url: str) -> str:
    """Chama POST /devices/{id}/provision e retorna o device_jwt."""
    url = f"{base_url}/devices/{device_id}/provision"
    req = urllib.request.Request(
        url,
        method="POST",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
        return data["device_jwt"]
    except urllib.error.HTTPError as exc:
        print(f"ERRO HTTP {exc.code} ao chamar {url}: {exc.read().decode()}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Grava o JWT do dispositivo na NVS do ESP32 via USB."
    )
    parser.add_argument(
        "--port",
        required=True,
        help="Porta serial (ex: COM3 no Windows, /dev/ttyUSB0 no Linux)",
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--jwt",
        help="JWT string obtido manualmente de POST /devices/{id}/provision",
    )
    group.add_argument(
        "--device-id",
        help="Device ID — o script busca o JWT automaticamente do backend",
    )

    parser.add_argument(
        "--access-token",
        help="Bearer token do usuário (obrigatório com --device-id)",
    )
    parser.add_argument(
        "--backend-url",
        default="http://localhost:8000",
        help="URL base do backend (padrão: http://localhost:8000)",
    )

    args = parser.parse_args()

    if args.device_id:
        if not args.access_token:
            parser.error("--access-token é obrigatório ao usar --device-id")
        print(f"Obtendo JWT para {args.device_id} em {args.backend_url}...")
        jwt = fetch_device_jwt(args.device_id, args.access_token, args.backend_url)
        print("JWT obtido.")
    else:
        jwt = args.jwt

    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
        bin_path = Path(f.name)

    try:
        print("Gerando binário da partição NVS...")
        generate_nvs_binary(jwt, bin_path)
        print(f"Binário gerado ({bin_path})")

        print(f"Gravando em {args.port} no endereço {NVS_PARTITION_ADDR}...")
        flash_nvs(args.port, bin_path)

        print("\nConcluído. NVS do ESP32 atualizado.")
        print(f"  namespace : {NVS_NAMESPACE}")
        print(f"  chave     : {NVS_KEY}")
        print(f"  endereço  : {NVS_PARTITION_ADDR}")
        print("\nReinicie o ESP32 para que o firmware carregue o novo JWT.")
    finally:
        bin_path.unlink(missing_ok=True)
