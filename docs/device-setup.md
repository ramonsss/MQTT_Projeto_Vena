# Guia de Setup do Dispositivo (ESP32)

Este guia descreve o processo completo para configurar um ESP32 Vena —
desde o primeiro flash até o device aparecer online no app.

> **Pré-requisitos de infraestrutura** (devem estar rodando antes de começar)
> - Docker: `cd infra && docker-compose up -d` (PostgreSQL + Mosquitto)
> - Backend: `cd backend && uvicorn app.main:app --reload --host 0.0.0.0`
> - Venv Python ativo: `.\venv\Scripts\activate`
> - `.env` na raiz com `PAIRING_SECRET`, `JWT_SECRET`, `GOOGLE_CLIENT_ID` preenchidos

---

## Fluxo completo (Fase 4 — BLE Provisioning)

A partir da Fase 4, **o JWT e as credenciais Wi-Fi são provisionados automaticamente
pelo app via BLE**. Não é necessário recompilar o firmware nem gravar nada
manualmente após o primeiro flash.

```
1. Flash do firmware  → ESP32 começa a fazer advertising BLE ("Vena-XXXX")
2. Seed do device     → registra o device no banco (uma vez por unidade)
3. Validar com nRF Connect → confirma que BLE está funcionando (opcional, mas recomendado)
4. App Flutter        → scan QR → BLE scan → provisioning Wi-Fi + JWT → claim
                        (a partir daqui o ESP32 está online sem mais intervenção)
```

> **Nota sobre o QR Code**: o QR deve conter o JSON
> `{"device_id":"vena-xxxxxxxxxxxx","pairing_code":"XXXX-XXXX"}`.
> O `device_id` é `vena-` + MAC sem separadores.
> O `pairing_code` é gerado deterministicamente do MAC no firmware (função `buildDeviceId()`).
> Para obter o pairing code sem o app, leia a seção [Obter o pairing code](#obter-o-pairing-code).

---

## Passo 1 — Flash do firmware

### 1a. Configurar credenciais de desenvolvimento (opcional)

Para testes sem app (ex.: desenvolvimento), crie o arquivo `firmware/platformio.local.ini`
(já está no `.gitignore`) com as credenciais da sua rede:

```ini
[env:esp32dev]
build_flags =
    ${common.build_flags}
    -DWIFI_SSID=\"NomeDaRede\"
    -DWIFI_PASS=\"SenhaDaRede\"
    -DMQTT_HOST=\"192.168.0.10\"
```

Sem esse arquivo, o ESP32 iniciará em **modo BLE-only** (sem Wi-Fi) e aguardará
provisioning via app — que é o fluxo normal de produção.

### 1b. Compilar e gravar

```powershell
cd firmware
pio run --target upload
```

### 1c. Abrir serial monitor

```powershell
pio device monitor
```

Saída esperada no boot:

```
[BOOT] device_id=vena-a0b765c1d2e3
[BOOT] ble_name=Vena-E3D2
[BLE] GATT service started, device=Vena-E3D2
[BLE] advertising started
[BOOT] Vena pronta (heap=XXXXX bytes)
```

> **Heap saudável**: valores acima de 100 000 bytes são normais com BLE + Wi-Fi ativos.
> Valores abaixo de 50 000 indicam problema de memória.

Copie o `device_id` exibido — você vai precisar dele no próximo passo.

---

## Passo 2 — Registrar o device no banco

Este passo é feito **uma única vez por unidade**, antes de qualquer provisioning.
Ele insere o device no PostgreSQL e gera o pairing code correspondente.

Com o venv ativo, dentro da pasta `backend/`:

```powershell
python scripts/seed_device.py --mac A0:B7:65:C1:D2:E3
```

Saída esperada:

```
Device 'vena-a0b765c1d2e3' inserted into DB.

========================================
  device_id   : vena-a0b765c1d2e3
  pairing code: A19F-09A3
========================================
```

> **De onde vem o MAC?** Está no `device_id` impresso no serial: `vena-a0b765c1d2e3`
> → MAC = `A0:B7:65:C1:D2:E3` (os 12 hex após `vena-`, reagrupados com `:`).

> **Por que o script?** O backend precisa conhecer o device antes de aceitar um claim.
> O script calcula o `pairing_code_hash` (bcrypt do pairing code) usando a mesma
> fórmula do firmware e grava na tabela `devices`.

---

## Passo 3 — Validar BLE com nRF Connect (recomendado)

Antes de usar o app, confirme que o BLE está funcionando corretamente.

### 3a. Instalar nRF Connect for Mobile
Disponível na Play Store (Android) e App Store (iOS).

### 3b. Verificar advertising
1. Aba **Scanner** → **Scan**
2. Procure `Vena-XXXX` na lista (os últimos 4 hex do MAC)
3. ✅ Device aparece com RSSI negativo (ex.: -55 dBm)

### 3c. Conectar e ler `device_info`
1. Tap em `Vena-XXXX` → **Connect**
2. Expanda o serviço `00000001-VENA-4F6C-8E12-A0B765C1D2E3`
3. Characteristic `00000002` → tap no ícone de **download (↓)** para Read
4. ✅ Exibe JSON: `{"device_id":"vena-...","fw_version":"1.1.0","capabilities":["telemetry","peltier"]}`

### 3d. Assinar telemetria ao vivo
1. Characteristic `00000003` → tap no ícone de **subscribe (sino)**
2. Aguarde 2 segundos
3. ✅ Valores aparecem e atualizam a cada ~2s:
   `{"ts":1748185200000,"at":22.5,"ah":65.0,"dt":18.3,"dh":60.1,"sp":18.0,"po":120}`

### 3e. Verificar wifi_status
1. Characteristic `00000004` → **Read**
2. Se ESP sem Wi-Fi: `{"connected":false}` ✅ normal neste ponto
3. Se já conectado (platformio.local.ini definido): `{"connected":true,"ssid":"...","ip":"...","rssi":-XX}`

> Após confirmar esses 4 pontos, **o firmware está validado** e o ESP32 não
> precisará ser reconectado ao computador novamente — o app cuida do resto.

---

## Passo 4 — Provisioning e claim via app Flutter

Este passo é feito dentro do próprio app pelo usuário final.

### 4a. Gerar o QR Code da unidade

O QR deve codificar o JSON (substitua pelos valores reais):

```json
{"device_id":"vena-a0b765c1d2e3","pairing_code":"A19F-09A3"}
```

Gere em qualquer gerador de QR online ou com o script:

```powershell
python scripts/generate_qr.py --device-id vena-a0b765c1d2e3 --pairing-code A19F-09A3
```

Cole/imprima o QR na unidade física.

### 4b. Fluxo no app (Fase 4)

```
Tela "Parear nova Vena"
  → Passo 1: Escanear QR code da unidade
  → Passo 2: App busca "Vena-XXXX" via BLE scan e conecta
  → Passo 3: App pede credenciais Wi-Fi (SSID + senha)
             App chama POST /devices/provision → recebe device_jwt
             App escreve {ssid, psk, jwt} via BLE characteristic 0x0005
             ESP32 conecta ao Wi-Fi + MQTT automaticamente
             App lê wifi_status até {"connected":true}
  → Passo 4: App chama POST /devices/{id}/claim
             Device aparece na lista "Minhas Venas"
```

> A partir daqui o device está **totalmente configurado**:
> - Wi-Fi e JWT gravados em NVS (persiste após desligar)
> - MQTT autenticado com o broker
> - BLE continua ativo para monitoramento local

---

## Obter o pairing code

O pairing code é gerado deterministicamente a partir do MAC no firmware
(veja `buildDeviceId()` em `firmware/src/main.cpp`):

```
pairing_code = sprintf("%02X%02X-%02X%02X",
    mac[0]^0x5A, mac[1]^0xA5, mac[2]^0x3C, mac[3]^0xC3)
```

Ou via script Python:

```python
mac = bytes.fromhex("a0b765c1d2e3")
xor = [0x5A, 0xA5, 0x3C, 0xC3]
code = f"{mac[0]^xor[0]:02X}{mac[1]^xor[1]:02X}-{mac[2]^xor[2]:02X}{mac[3]^xor[3]:02X}"
print(code)  # ex: FA12-5946
```

Ou via nRF Connect (requer bonding):
1. Conecte e faça bond com a unidade
2. Characteristic `00000006` → Read
3. Retorna o pairing code diretamente

---

## Verificação final

Com tudo configurado, confirme no serial monitor do ESP32:

```
[BOOT] device_id=vena-a0b765c1d2e3
[BLE] advertising started
[PROV] credentials saved: ssid=NomeDaRede
[PROV] WiFi connected, IP=192.168.0.42
[NTP] sincronizado apos provisioning
Connecting to MQTT broker...
MQTT connected as vena-a0b765c1d2e3
```

E no app: device aparece na lista com badge **online** e temperatura em tempo real.

---

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| ESP não aparece no nRF Connect | BLE não inicializou | Ver serial: `[BLE] GATT service started` deve aparecer |
| `heap < 50000` no boot | Memória insuficiente | Reduzir `OFFLINE_BUFFER_SIZE` em `config.h` |
| `MQTT_USE_AUTH=1` mas sem JWT | NVS vazio antes do provisioning | Normal — app provisiona via BLE |
| Provisioning falha (Wi-Fi não conecta) | SSID/senha errados | Refazer provisioning via app |
| `POST /devices/provision` retorna 404 | Device não foi seedado | Rodar `seed_device.py` (Passo 2) |
| `POST /devices/provision` retorna 403 | Pairing code errado | Verificar fórmula XOR; usar nRF Connect para ler characteristic 0x0006 |
| Device perde Wi-Fi após desligar | NVS corrompido | `pio run -t upload` apaga NVS; refazer provisioning |
| Broker recusa conexão (`not authorized`) | JWT expirado ou `JWT_SECRET` diferente | Refazer provisioning (gera novo JWT) |

---

## Para deploy em servidor de testes

Execute em ordem após o deploy:

```bash
# 1. Aplicar migrations
alembic upgrade head

# 2. Seed dos devices (repita para cada ESP32)
python scripts/seed_device.py --mac A0:B7:65:C1:D2:E3

# 3. Flash do firmware em cada unidade (Passo 1)

# 4. Provisioning via app (Passo 4) — sem mais passos manuais
```
