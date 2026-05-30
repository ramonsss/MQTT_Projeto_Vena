# Fase 1 — Telemetria End-to-End Mínima

> **Objetivo**: ESP32 publica telemetria com device_id dinâmico e timestamp real → backend ingere via MQTT → persiste em PostgreSQL → REST devolve histórico.
>
> **Pré-requisito**: Fase 0 concluída (Docker Compose rodando Postgres + Mosquitto, FastAPI skeleton com Alembic, models de identidade).

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | Device ID no firmware | `vena-` + MAC lowercase sem `:` via `ESP.getEfuseMac()`. String de 17 chars (`vena-xxxxxxxxxxxx`). |
| 2 | NTP antes de publicar? | Sim. Firmware bloqueia publish até NTP sincronizar. Usa `configTime()` do ESP32 (pool: `pool.ntp.org`). Timeout: 10s. Se falhar, usa `uptime_ms` como fallback (backend marca `ts` do receive). |
| 3 | Tópico de telemetria | `vena/{deviceId}/telemetry`. Client ID MQTT = `device_id`. Ainda anônimo (auth na Fase 2). |
| 4 | Tópico de status (LWT) | `vena/{deviceId}/status` com retain=true. Will payload: `{"online":false}`. Após connect publica `{"online":true}`. |
| 5 | Payload: campos `ts` e `seq` | `ts` = epoch milliseconds (int64). `seq` = contador monotônico (uint32, reseta em reboot). |
| 6 | QoS telemetry | QoS 1 (at-least-once). Buffer offline já garante entrega eventual. |
| 7 | Tabela `telemetry_raw` | PK composta `(device_id, ts)` com `ON CONFLICT DO NOTHING` para idempotência. |
| 8 | Batch insert no worker | Fila in-memory (asyncio.Queue). Flush a cada **1s** ou **100 msgs** (o que vier primeiro). Usa `executemany`. |
| 9 | History API — granularidade mínima | Retorna raw ordenado por `ts DESC` com paginação `limit` + `offset`. Sem agregação ainda. |
| 10 | Auto-register device | Se o worker recebe telemetria de um `device_id` desconhecido, cria o registro em `devices` com status `online`, `first_seen_at = now()`, e `pairing_code_hash = 'unprovisioned'`. |

---

## Contratos

### MQTT payload: `vena/{deviceId}/telemetry`

```json
{
  "ts": 1716220800000,
  "ambient_t": 22.5,
  "ambient_h": 65.2,
  "diss_t": 18.3,
  "diss_h": 60.1,
  "setpoint": 18.0,
  "pid_out": 120.0,
  "uptime_ms": 45000,
  "seq": 9
}
```

### MQTT payload: `vena/{deviceId}/status`

```json
{"online": true, "fw_version": "1.1.0", "uptime_ms": 45000}
```

### REST: `GET /devices/{device_id}/history`

**Query params**:
| Param | Tipo | Default | Descrição |
|-------|------|---------|-----------|
| `start` | ISO 8601 datetime | 24h atrás | início do range |
| `end` | ISO 8601 datetime | agora | fim do range |
| `limit` | int | 500 | max linhas |
| `offset` | int | 0 | paginação |

**Response 200**:
```json
{
  "device_id": "vena-a0b765c1d2e3",
  "count": 120,
  "samples": [
    {"ts": "2026-05-20T10:00:00Z", "ambient_t": 22.5, "ambient_h": 65.2, "diss_t": 18.3, "diss_h": 60.1, "setpoint": 18.0, "pid_out": 120.0},
    ...
  ]
}
```

**Response 404**: device não existe.

---

## Checklist de implementação

### A. Firmware (refactor mínimo)

| # | Arquivo | Mudança |
|---|---------|---------|
| A1 | `config.h` | Remover `MQTT_CLIENT_ID`, `MQTT_TOPIC_TELEMETRY`, `MQTT_TOPIC_CMD` hardcoded. Adicionar `NTP_SERVER`, `NTP_TIMEOUT_MS`, `FW_VERSION`. |
| A2 | `MqttPublisher.h/.cpp` | Aceitar `deviceId` como parâmetro (derivado do MAC). Construir tópicos dinamicamente: `"vena/" + deviceId + "/telemetry"`. Configurar LWT em `status`. Subir QoS para 1. |
| A3 | `main.cpp` | No `setup()`: (1) derivar `deviceId` do MAC, (2) chamar `configTime()` e aguardar sync, (3) passar `deviceId` ao `MqttPublisher`. No `buildTelemetryJson()`: adicionar `ts` (via `time()` * 1000) e `seq` (contador global). |
| A4 | `OfflineBuffer` | Sem mudança funcional — payload já carrega `ts` real. Buffer continua operando igual. |
| A5 | `platformio.ini` | Verificar se `build_flags` ainda tem fallbacks para SSID/PASS/HOST via `platformio.local.ini`. Remover referência ao client_id. |

### B. Backend — Model `TelemetryRaw`

| # | Arquivo | Mudança |
|---|---------|---------|
| B1 | `app/db/models.py` | Adicionar model `TelemetryRaw` com PK `(device_id, ts)`. |
| B2 | Alembic migration | `alembic revision --autogenerate -m "add_telemetry_raw"` → `alembic upgrade head`. |

### C. Backend — MQTT Worker

| # | Arquivo | O que faz |
|---|---------|-----------|
| C1 | `app/mqtt/__init__.py` | Package init. |
| C2 | `app/mqtt/worker.py` | Classe `MqttWorker`: thread Paho + asyncio.Queue. Subscribe `vena/+/telemetry` e `vena/+/status`. Backoff exponencial na reconexão. |
| C3 | `app/mqtt/topics.py` | Função `parse_topic(topic: str) -> tuple[str, str]` que extrai `(device_id, message_type)` de `vena/{id}/{type}`. |
| C4 | `app/telemetry/__init__.py` | Package init. |
| C5 | `app/telemetry/ingest.py` | Classe `TelemetryIngestor`: consome da Queue, valida payload, faz batched insert. Auto-register de device desconhecido. |
| C6 | `app/main.py` | No `lifespan`: instanciar `MqttWorker` + `TelemetryIngestor`, iniciar ambos; no shutdown, parar e drenar fila. |

### D. Backend — REST History

| # | Arquivo | O que faz |
|---|---------|-----------|
| D1 | `app/telemetry/schemas.py` | Pydantic models: `TelemetrySample`, `HistoryResponse`, `HistoryQuery`. |
| D2 | `app/telemetry/history.py` | Função `get_history(session, device_id, start, end, limit, offset)` → query `telemetry_raw`. |
| D3 | `app/telemetry/routes.py` | Router com `GET /devices/{device_id}/history`. Depende de `get_session`. |
| D4 | `app/main.py` | Registrar router: `app.include_router(telemetry_router)`. |

### E. Teste de integração

| # | O que valida |
|---|---|
| E1 | Publicar 5 mensagens MQTT simuladas → verificar 5 rows em `telemetry_raw`. |
| E2 | Publicar mensagem duplicada (mesmo `device_id` + `ts`) → count não muda. |
| E3 | `GET /history` retorna amostras ordenadas por `ts DESC` dentro do range. |
| E4 | Device desconhecido → criado automaticamente com status `online`. |

---

## Modelo SQLAlchemy: `TelemetryRaw`

```python
class TelemetryRaw(Base):
    __tablename__ = "telemetry_raw"

    device_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True
    )
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), primary_key=True
    )
    ambient_t: Mapped[float | None] = mapped_column(nullable=True)
    ambient_h: Mapped[float | None] = mapped_column(nullable=True)
    diss_t: Mapped[float | None] = mapped_column(nullable=True)
    diss_h: Mapped[float | None] = mapped_column(nullable=True)
    setpoint: Mapped[float | None] = mapped_column(nullable=True)
    pid_out: Mapped[float | None] = mapped_column(nullable=True)
    uptime_ms: Mapped[int | None] = mapped_column(nullable=True)
    seq: Mapped[int | None] = mapped_column(nullable=True)
```

---

## Design do MQTT Worker

```
┌─────────────────────────────────────────────────────────┐
│  FastAPI Process (asyncio event loop)                    │
│                                                         │
│  ┌──────────────────┐     asyncio.Queue     ┌────────┐ │
│  │  Paho Thread     │ ────────────────────▶ │Ingestor│ │
│  │  - on_message()  │  (device_id, payload) │ (async)│ │
│  │  - reconnect     │                       │ batch  │ │
│  │  - sub vena/+/#  │                       │ insert │ │
│  └──────────────────┘                       └────────┘ │
│            ▲                                     │      │
│            │ loop_start()                        ▼      │
│            │                              ┌──────────┐  │
│            │                              │ Postgres │  │
│            │                              └──────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Comportamento**:
1. `MqttWorker.start()` → `paho.loop_start()` (thread interna).
2. `on_connect` → subscribe `vena/+/telemetry`, `vena/+/status`.
3. `on_message` → `queue.put_nowait((topic, payload_bytes))`.
4. `TelemetryIngestor` roda como `asyncio.Task`:
   - `await asyncio.wait_for(queue.get(), timeout=1.0)` em loop.
   - Acumula em batch list.
   - Flush quando `len(batch) >= 100` ou `1s` desde último flush.
   - Insert: `INSERT INTO telemetry_raw (...) VALUES (...) ON CONFLICT DO NOTHING`.
5. `on_disconnect` → backoff 1s → 2s → 4s → ... → 30s cap.

---

## Mudanças no firmware (pseudocódigo das alterações)

### `config.h` (novos defines)

```cpp
#ifndef NTP_SERVER
#define NTP_SERVER "pool.ntp.org"
#endif
#ifndef NTP_TIMEOUT_MS
#define NTP_TIMEOUT_MS 10000
#endif
#ifndef FW_VERSION
#define FW_VERSION "1.1.0"
#endif
// Removidos: MQTT_CLIENT_ID, MQTT_TOPIC_TELEMETRY, MQTT_TOPIC_CMD
```

### `main.cpp` — derivação do device_id

```cpp
#include <esp_mac.h>

static char deviceId[20];  // "vena-xxxxxxxxxxxx\0"

static void buildDeviceId() {
    uint8_t mac[6];
    esp_efuse_mac_get_default(mac);
    snprintf(deviceId, sizeof(deviceId), "vena-%02x%02x%02x%02x%02x%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}
```

### `main.cpp` — NTP sync no setup

```cpp
static bool waitForNtp() {
    configTime(0, 0, NTP_SERVER);
    unsigned long start = millis();
    while (time(nullptr) < 1000000000UL) {  // antes de 2001 = não sincronizou
        if (millis() - start > NTP_TIMEOUT_MS) return false;
        delay(100);
    }
    return true;
}
```

### `buildTelemetryJson()` — novos campos

```cpp
static uint32_t seqCounter = 0;

static String buildTelemetryJson() {
    JsonDocument doc;
    doc["ts"] = (int64_t)time(nullptr) * 1000LL;  // epoch ms
    doc["seq"] = seqCounter++;
    doc["ambient_t"] = lastAmbT;
    doc["ambient_h"] = lastAmbH;
    doc["diss_t"] = lastDissT;
    doc["diss_h"] = lastDissH;
    doc["setpoint"] = peltier.currentSetpoint();
    doc["pid_out"] = peltier.lastOutput();
    doc["uptime_ms"] = (uint32_t)millis();
    String out;
    serializeJson(doc, out);
    return out;
}
```

### `MqttPublisher` — tópicos dinâmicos + LWT

```cpp
// Constructor recebe deviceId ao invés de topic strings fixas.
// Internamente constrói:
//   _topicTelemetry = "vena/" + deviceId + "/telemetry"
//   _topicStatus    = "vena/" + deviceId + "/status"
//   _topicCmd       = "vena/" + deviceId + "/cmd"
//
// No connect():
//   _mqtt.setWill(_topicStatus.c_str(), 1, true, "{\"online\":false}");
//
// Após connectado:
//   publish(_topicStatus, "{\"online\":true,\"fw_version\":\"" FW_VERSION "\"}", true);
```

---

## Critérios de aceite (DoD)

| # | Critério | Como verificar |
|---|----------|----------------|
| 1 | ESP32 publica com device_id baseado em MAC | Monitor serial mostra `[BOOT] device_id=vena-xxxxxxxxxxxx` |
| 2 | Timestamp `ts` é epoch ms real (não millis) | Payload no broker: `ts > 1700000000000` |
| 3 | `seq` incrementa monotonicamente | Subscribe no mosquitto_sub, verificar seq +1 a cada 5s |
| 4 | LWT funciona | Desligar ESP → `vena/{id}/status` retained mostra `{"online":false}` |
| 5 | Backend recebe e persiste | `SELECT count(*) FROM telemetry_raw WHERE device_id='vena-...'` cresce ~12/min |
| 6 | Idempotência | Republicar mesma msg → count não muda |
| 7 | Auto-register | Device novo aparece em `SELECT * FROM devices` com status `online` |
| 8 | REST history | `curl /devices/vena-.../history` retorna amostras recentes em JSON |
| 9 | Offline buffer preservado | Desligar Wi-Fi 30s → religar → amostras com `ts` corretos aparecem no banco em sequência |
| 10 | Backend reconecta ao broker | Reiniciar Mosquitto → backend reconecta (log mostra) em <30s |

---

## Armadilhas conhecidas

| Problema | Solução |
|----------|---------|
| `time()` retorna 0 se NTP não sincronizou | `waitForNtp()` bloqueia setup; se timeout → não publica (usa flag `ntpReady`) |
| `esp_efuse_mac_get_default()` retorna bytes em big-endian no ESP32-S3, little-endian no ESP32 original | Testar no hardware real; se necessário usar `WiFi.macAddress()` como fallback |
| Paho `on_message` é chamado na thread Paho; colocar na Queue sem blocking | Usar `put_nowait`; se Queue cheia (improvável com 100 flush), dropar com log warning |
| `MQTT_BUFFER_SIZE=512` pode ser curto com novos campos | Payload máximo agora ~220 bytes. 512 é suficiente, mas validar com `measureJson()` |
| `asyncpg` não aceita `datetime` naive | Sempre converter `ts` epoch → `datetime.fromtimestamp(ts/1000, tz=timezone.utc)` |
| Device auto-registered sem `pairing_code_hash` | Usar valor placeholder `'unprovisioned'`; claim na Fase 2 atualiza para hash real |
| PostgreSQL PK em `(device_id, ts)` sem partição pode ficar lenta com milhões de linhas | Aceitável para Fase 1 (< 100k rows); TimescaleDB hypertable na Fase 5 resolve |

---

## Ordem de execução recomendada

```
1. [Firmware] A1-A2: config.h + MqttPublisher refatorado (tópicos dinâmicos, LWT)
2. [Firmware] A3: main.cpp (deviceId, NTP, ts, seq)
3. [Firmware] Upload + verificar no mosquitto_sub que payloads estão corretos
4. [Backend]  B1-B2: TelemetryRaw model + migration
5. [Backend]  C1-C3: MQTT worker + topic parser
6. [Backend]  C4-C5: TelemetryIngestor
7. [Backend]  C6: integrar worker no lifespan
8. [Backend]  Verificar: telemetria aparecendo em SELECT
9. [Backend]  D1-D4: REST /history
10. [E2E]     E1-E4: testes de integração
```

---

## Métricas de sucesso (smoke test final)

1. ESP32 ligado por 5 minutos → `SELECT count(*) FROM telemetry_raw` retorna ~60 linhas.
2. `curl http://localhost:8000/devices/vena-XXXX/history?limit=10` retorna 10 amostras recentes com `ts` real.
3. Desligar ESP32, verificar `vena/{id}/status` retained = `{"online":false}`.
4. Religar ESP32 com Wi-Fi desligado por 2min → ligar Wi-Fi → verificar que as amostras do período offline chegam com `ts` correto e `seq` contíguos.
