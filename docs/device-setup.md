# Guia de Setup do Dispositivo (ESP32)

Este guia descreve o processo completo para registrar um ESP32 no sistema e
conectá-lo ao broker MQTT autenticado.

> **Pré-requisitos**
> - Docker rodando (`docker-compose up -d` na pasta `infra/`)
> - Backend rodando (`uvicorn app.main:app --reload` na pasta `backend/`)
> - Venv ativo (`.\venv\Scripts\activate`)
> - `.env` com `PAIRING_SECRET` preenchido

---

## Visão geral

```
1. Flash do firmware → Serial Monitor mostra o MAC do ESP32
2. Seed do device    → insere o device no banco com pairing code
3. Claim             → usuário associa o device à sua conta
4. Provision JWT     → gera o JWT de longa duração para o ESP32
5. Gravar JWT no NVS → ESP32 usa o JWT para autenticar no broker
```

---

## Passo 1 — Obter o MAC do ESP32

Adicione temporariamente ao `setup()` no firmware:

```cpp
Serial.begin(115200);
Serial.println(WiFi.macAddress());  // ex: A0:B7:65:C1:D2:E3
```

Faça o upload (`pio run -t upload`) e abra o Serial Monitor.
Copie o MAC exibido.

> Você pode remover a linha depois — o MAC está gravado em hardware e não muda.

---

## Passo 2 — Registrar o device no banco

Com o venv ativo, dentro da pasta `backend/`:

```powershell
python scripts/seed_device.py --mac A0:B7:65:C1:D2:E3
```

Saída esperada:

```
Device 'vena-a0b765c1d2e3' inserted into DB.

========================================
  device_id   : vena-a0b765c1d2e3
  pairing code: A19F09A3
========================================

Use the pairing code above with:
  POST /devices/vena-a0b765c1d2e3/claim
  body: { "pairing_code": "A19F09A3" }
```

Guarde o `device_id` e o `pairing code`.

---

## Passo 3 — Fazer login e claim do device (via app ou curl)

### 3a. Login com Google

```bash
curl -X POST http://localhost:8000/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "<seu_google_id_token>"}'
```

Resposta:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "...",
  ...
}
```

Guarde o `access_token`.

### 3b. Claim do device

```bash
curl -X POST http://localhost:8000/devices/vena-a0b765c1d2e3/claim \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"pairing_code": "A19F09A3"}'
```

Resposta:
```json
{
  "device_id": "vena-a0b765c1d2e3",
  "alias": null,
  "claimed_at": "2026-05-23T..."
}
```

---

## Passo 4 — Gerar o JWT do dispositivo

```bash
curl -X POST http://localhost:8000/devices/vena-a0b765c1d2e3/provision \
  -H "Authorization: Bearer <access_token>"
```

Resposta:
```json
{
  "device_jwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 31536000
}
```

Copie o valor de `device_jwt`.

---

## Passo 5 — Gravar o JWT no NVS do ESP32

### Opção A: Script Python via USB (recomendado)

```python
# Requer: pip install esptool
# Execute uma vez com o ESP32 conectado via USB
import subprocess, sys

JWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."  # cole aqui
PORT = "COM3"  # ajuste para sua porta

# Grava via nvs_flash usando o namespace "vena", chave "device_jwt"
# (requer que o firmware implemente nvs_load_jwt() — Fase 2 G3)
```

> **Fase 2 simplificada**: por ora, grave o JWT diretamente na
> `config.h` como constante e recompile o firmware.

### Opção B: Hardcoded em `config.h` (dev only)

```cpp
// firmware/include/config.h
#define MQTT_USE_AUTH     1
#define DEVICE_JWT        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Recompile e faça o upload. O firmware lerá o JWT de `DEVICE_JWT` e o
usará como `username` no MQTT connect.

> Na Fase 4, o JWT será provisionado via BLE e armazenado no NVS
> automaticamente, sem necessidade de recompilar.

---

## Verificação

Com o firmware rodando, verifique no Serial Monitor:

```
Connecting to MQTT broker...
MQTT connected as vena-a0b765c1d2e3
```

Se a conexão for rejeitada (`Connection refused, not authorized`),
verifique:
- O JWT não expirou (validade de 1 ano)
- O `JWT_SECRET` no `.env` é o mesmo que foi usado para gerar o JWT
- O broker está com `allow_anonymous false` ativo

---

## Para deploy em servidor de testes

Execute em ordem após o deploy:

```bash
# 1. Aplicar migrations
alembic upgrade head

# 2. Seed dos devices (repita para cada ESP32)
python scripts/seed_device.py --mac A0:B7:65:C1:D2:E3

# 3. Claim + provision via curl (passos 3 e 4 acima)
```
