# Plan: Vena — Arquitetura Completa (IoT + Mobile + Backend)

> Produto IoT offline-first para produtores rurais. Cada **Vena** é uma unidade ESP32 com sensores DHT22 (ambiente + dissipador) e atuação Peltier (PID cooling). App Flutter monitora local (BLE) e remoto (MQTT). Backend Python persiste telemetria em PostgreSQL e gerencia usuários/dispositivos.

## Decisões críticas alinhadas com o usuário
- **Backend**: **Python (FastAPI + Paho + SQLAlchemy/Alembic + PostgreSQL)** — descarta-se a ideia de NestJS; reaproveita-se o serviço Paho atual com refactor.
- **Atuação**: MVP **somente monitoramento**. O comando `setpoint` existente fica acessível apenas em rota admin/dev (não exposto na UI de produtor).
- **Auth MQTT**: app conecta **diretamente** ao broker com **JWT dinâmico** validado por `mosquitto-go-auth` (plugin JWT). Backend emite tokens com claims escopadas por usuário → dispositivos.
- **Firmware**: refactor completo planejado (ID por MAC/chipId, BLE GATT, tópicos `vena/{deviceId}/...`, auth MQTT por device). Caso a complexidade do BLE estoure prazo, BLE vai para Fase posterior (roadmap marca o ponto exato de corte).

---

## 1. System Design (visão macro)

```
┌──────────────┐  BLE GATT (local)           ┌────────────────────────┐
│  Vena ESP32  │ ─────────────────────────▶ │ Flutter App (Riverpod) │
│ DHT22 x2     │                            │ Drift/SQLite (cache)   │
│ Peltier+PID  │ ─MQTT TLS─▶ Mosquitto ◀─MQTT─ JWT auth (per session)│
└──────┬───────┘             │      ▲     └──────────┬─────────────┘
       │                     │      │                │ REST/HTTPS
       │                     │      │                ▼
       │                     │      │     ┌────────────────────────┐
       │                     │      │     │ FastAPI Backend (Py)   │
       │                     │      └─────│ - Auth/JWT issuer      │
       │                     │            │ - User & Device mgmt   │
       │                     ▼            │ - History API          │
       │            ┌────────────────┐    │ - Aggregation jobs     │
       │            │ MQTT Worker    │◀───│ - mosquitto-go-auth API│
       │            │ (Paho asyncio) │    └────────────┬───────────┘
       │            │ persists →     │                 │
       │            └────────┬───────┘                 │
       │                     ▼                         ▼
       │            ┌─────────────────────────────────────┐
       └───────────▶│   PostgreSQL (raw + agregados)      │
                    │   + TimescaleDB extension (opcional)│
                    └─────────────────────────────────────┘
```

**Princípios-chave**
1. **UI sempre lê do SQLite local**. BLE/MQTT/REST apenas alimentam o cache.
2. **Source-of-truth de identidade do device**: backend PostgreSQL. ESP32 publica usando ID derivado do MAC.
3. **Backend é o emissor de JWT**. Broker não conhece usuários — só valida JWTs.
4. **Telemetria raw é write-once**, agregados são computados.

---

## 2. Identificação do dispositivo

Análise do código atual: ID hardcoded `cocoa-box-01`. Não escala.

**Estratégia recomendada** (combina robustez + UX de pareamento):
- **`device_id` interno** = `vena-` + **MAC base do ESP32 sem `:`** (ex.: `vena-a0b765c1d2e3`). Imutável, único por hardware, lido via `esp_efuse_mac_get_default()`.
- **`pairing_code`** = SHA-256(MAC + factory_secret) truncado a **8 caracteres alfanuméricos** (ex.: `K7X9-M2P4`). Impresso em **QR code** colado na unidade. Usuário escaneia para parear.
- **BLE advertised name** = `Vena-<últimos-4-do-MAC>` (ex.: `Vena-D2E3`) para descoberta visual.
- **Claim no backend**: usuário envia `pairing_code` → backend valida → cria relação `user_devices`. Após claim, qualquer login do mesmo user vê o device remotamente.

**Por que não UUID v4 gerado em runtime?** Perde-se ao reflashar. MAC é imutável e já único globalmente.

---

## 3. Estrutura de tópicos MQTT (substitui `cocoa/box01/*`)

```
vena/{deviceId}/telemetry      ← publish (device → broker)        QoS 1, retain=false
vena/{deviceId}/status         ← publish (device → broker)        QoS 1, retain=TRUE  (LWT online/offline)
vena/{deviceId}/cmd/setpoint   ← subscribe (broker → device)      QoS 1
vena/{deviceId}/cmd/ack        ← publish (device → broker)        QoS 1
vena/{deviceId}/meta           ← publish on boot (retain=true)    QoS 1  (firmware ver, capabilities)
```

**LWT (Last Will and Testament)**: device declara `{"online":false}` retained em `status` ao se conectar; envia `{"online":true,...}` após handshake. Permite app saber em <keepalive segundos se device caiu.

**Payload telemetry (mantém campos atuais + metadados)**:
```json
{
  "ts": 1737830400000,
  "ambient_t": 22.5,
  "ambient_h": 65.2,
  "diss_t": 18.3,
  "diss_h": 60.1,
  "setpoint": 18.0,
  "pid_out": 120,
  "uptime_ms": 12345,
  "seq": 4821
}
```

**Frequência**: 5s (mantém atual). Em modo offline-buffer, ESP envia em lote com timestamps reais (cada msg leva o `ts` em que foi medida).

---

## 4. Autenticação & ACL

**Stack**: Mosquitto 2.x + `mosquitto-go-auth` (backend HTTP) + TLS (LetsEncrypt).

**Fluxo app**:
1. App faz Google OAuth → backend valida → retorna `access_token` (JWT) + `refresh_token`.
2. App pede `POST /mqtt/credentials` → backend gera **JWT MQTT de curta duração** (1h) com claims:
   ```json
   { "sub":"user:42", "devices":["vena-a0b...","vena-b1c..."], "scope":"app", "exp":... }
   ```
3. App conecta no broker com `username=<jwt>`, `password=` vazio.
4. `mosquitto-go-auth` chama backend `POST /mqtt/auth` e `POST /mqtt/acl` → backend valida claim por tópico (regex `vena/{deviceId}/.*` ⊂ devices do user).
5. App refaz refresh do JWT 5 min antes do `exp`; reconecta se broker derrubar.

**Fluxo device**: cada Vena recebe na primeira inicialização (provisioning Wi-Fi via BLE) um **device JWT longo-prazo** assinado pelo backend, com scope `device` e claim `device_id`. ACL: device só pode publish em `vena/{seu_id}/*` e subscribe em `vena/{seu_id}/cmd/*`.

**Backend**: tem identidade própria (`scope=backend`) com ACL `vena/+/telemetry` e `vena/+/status` (read-only) e `vena/+/cmd/setpoint` (publish, admin).

---

## 5. Fluxo BLE (refactor de firmware)

**Serviços GATT** (UUIDs custom 128-bit, namespace Vena):
- **Vena Service** `0000VENA-...`
  - `device_info` (read) — JSON: `{device_id, fw_version, capabilities}`
  - `live_telemetry` (notify) — broadcast a cada 2s do payload sem buffer
  - `wifi_provisioning` (write/read) — recebe `{ssid, psk, jwt_device}`; retorna status
  - `pairing_code` (read, requires bonding) — retorna `pairing_code` para o app

**Descoberta**: app escaneia 8s buscando manuf data `0xVENA`; lista devices próximos.

**Estados no app** (state machine BLE):
```
idle → scanning → discovered → connecting → bonded → subscribed → streaming
                                    │
                                    └─error→ retry com backoff (1s,2s,4s,…30s, cap)
```

**Reconnect resiliente**:
- iOS: usa `restoreIdentifier` → SO reconecta em background
- Android: `autoConnect=true` no `connectGatt`; foreground service só durante stream contínuo
- App mantém **uma única conexão BLE ativa por vez** (limitação iOS) — escolhe o device da tela atual.

**Permissões**:
- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, sem necessidade de `ACCESS_FINE_LOCATION` se `neverForLocation=true` no scan.
- Android ≤11: `ACCESS_FINE_LOCATION` obrigatório (limitação do SO).
- iOS: `NSBluetoothAlwaysUsageDescription` + `bluetooth-central` em `UIBackgroundModes`.

**Lib Flutter**: `flutter_reactive_ble` (preferido — bonding, restore, melhor que `flutter_blue_plus` para produção).

---

## 6. Fluxo MQTT no app

**Lib**: `mqtt_client` (Dart) com transport TCP+TLS (porta 8883).

**Lifecycle**:
1. App login → fetch JWT MQTT → conecta ao broker.
2. Subscribe a `vena/+/telemetry` e `vena/+/status` (filtrado por claim ACL — o broker bloqueia tópicos fora do escopo).
3. Para cada mensagem: parse → grava SQLite → notifica listeners Riverpod.
4. Em background (app em foreground perdido): mantém conexão por **30s** após ir para background; depois desconecta para poupar bateria. Reconecta em foreground retornado.

**Reconexão**:
- Backoff exponencial 1s → 60s.
- Renovação de JWT 5min antes de expirar.
- Se broker recusa (jwt expired), força refresh do access_token via backend e reconecta.

---

## 7. Estratégia Offline-First

**Princípio fundamental**:
```
BLE listener  ─┐
MQTT listener ─┼─▶ Drift/SQLite  ─▶  Riverpod streams  ─▶  UI
REST sync     ─┘
```
A UI nunca conhece a origem dos dados. Apenas marca **`source: ble|mqtt|api`** em cada amostra para o badge "conectado localmente / remotamente".

**Resolução de conflitos** (mesmo timestamp via BLE e MQTT):
- Chave única `(device_id, ts, source)` em telemetry_cache.
- Para `latest_state` (uma linha por device): UPSERT com `WHERE new.ts > old.ts` — mais recente vence, independente de source.

**Outbox pattern** para writes (claim, rename, etc.):
- App grava localmente em tabela `outbox` com `synced=false`.
- Worker tenta enviar ao backend; em sucesso marca `synced=true`.
- Conflitos: backend retorna `409` com versão atual; app aplica resolução (server wins p/ identidade, last-write-wins p/ alias).

---

## 8. Modelagem dos bancos

### PostgreSQL (backend)

```sql
-- Identidade
users (
  id uuid pk,
  google_sub text unique,
  email text,
  created_at timestamptz
)

devices (
  id text pk,                      -- "vena-a0b765c1d2e3"
  pairing_code_hash text not null, -- bcrypt do pairing code
  fw_version text,
  capabilities jsonb,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  status text                      -- online|offline|never_connected
)

user_devices (                     -- N:N
  user_id uuid fk,
  device_id text fk,
  alias text,                      -- nome local DO USUÁRIO
  claimed_at timestamptz,
  pk (user_id, device_id)
)

-- Telemetria raw (hot)
telemetry_raw (
  device_id text fk,
  ts timestamptz,
  ambient_t real, ambient_h real,
  diss_t real, diss_h real,
  setpoint real, pid_out real,
  uptime_ms bigint, seq bigint,
  pk (device_id, ts)
)
-- → considerar TimescaleDB hypertable

-- Telemetria agregada (warm/cold)
telemetry_1m (device_id, bucket_ts, ambient_t_avg, ambient_t_min, ambient_t_max, ... )
telemetry_1h (device_id, bucket_ts, ...)
telemetry_1d (device_id, bucket_ts, ...)

-- Limites (para alertas futuros)
device_thresholds (
  device_id fk, user_id fk,
  ambient_t_min real, ambient_t_max real,
  ambient_h_min real, ambient_h_max real,
  notify_enabled bool
)

-- Eventos/Auditoria
device_events (id, device_id, type, payload jsonb, ts)  -- online/offline/cmd_sent/...
```

**Retenção**:
- `telemetry_raw`: 30 dias (continuous aggregate alimenta `telemetry_1m`).
- `telemetry_1m`: 90 dias.
- `telemetry_1h`: 1 ano.
- `telemetry_1d`: 5 anos.
- Limpeza via TimescaleDB retention policy ou cron `DELETE WHERE ts < now() - interval`.

### SQLite (Drift, app)

```dart
@DataClassName('LatestState')
class LatestStates extends Table {  // 1 linha por device (current snapshot)
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real().nullable()();
  RealColumn get ambientH => real().nullable()();
  RealColumn get dissT => real().nullable()();
  RealColumn get dissH => real().nullable()();
  TextColumn get source => text()();   // 'ble'|'mqtt'|'api'
  BoolColumn get online => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {deviceId};
}

class TelemetryCache extends Table {  // ring buffer p/ gráficos rápidos
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real()();
  // ... só campos necessários p/ chart
  @override Set<Column> get primaryKey => {deviceId, ts};
}
// Manter últimas 1000 amostras por device (≈ 1.4h a 5s/sample). Resto pede ao backend.

class Devices extends Table {     // metadata local
  TextColumn get deviceId => text()();
  TextColumn get alias => text()();
  IntColumn get lastSeenAt => integer().nullable()();
  TextColumn get capabilities => text().nullable()(); // JSON
}

class Outbox extends Table { ... }       // sync queue
class UserSession extends Table { ... }  // tokens criptografados
```

---

## 9. Estrutura Backend (FastAPI)

```
backend/
├── pyproject.toml          # poetry; deps: fastapi, uvicorn, paho-mqtt,
│                           # sqlalchemy, alembic, asyncpg, pydantic,
│                           # python-jose (JWT), bcrypt, httpx
├── alembic/
├── app/
│   ├── main.py             # FastAPI app + lifespan (start MQTT worker)
│   ├── config.py           # Pydantic Settings (.env)
│   ├── db/
│   │   ├── session.py      # async engine, sessionmaker
│   │   ├── models.py       # SQLAlchemy ORM
│   │   └── migrations/     # alembic versions
│   ├── auth/
│   │   ├── google.py       # OAuth2 verify
│   │   ├── jwt.py          # issue/verify backend JWT + MQTT JWT
│   │   └── routes.py       # /auth/google, /auth/refresh
│   ├── devices/
│   │   ├── service.py      # claim, list, rename(alias)
│   │   ├── routes.py       # REST /devices, /devices/{id}/claim
│   │   └── schemas.py      # Pydantic DTOs
│   ├── telemetry/
│   │   ├── ingest.py       # MQTT callback → insert raw
│   │   ├── aggregator.py   # cron 1min/1h/1d (APScheduler)
│   │   ├── history.py      # query layer p/ gráficos
│   │   └── routes.py       # GET /devices/{id}/history?range=24h&bucket=1m
│   ├── mqtt/
│   │   ├── worker.py       # paho client async, reconnect com backoff
│   │   ├── topics.py       # parsing vena/{id}/telemetry|status|...
│   │   └── publisher.py    # publish_setpoint(device_id, value, user_id)
│   ├── broker_auth/        # endpoints chamados pelo mosquitto-go-auth
│   │   └── routes.py       # /mqtt/auth, /mqtt/acl, /mqtt/superuser
│   └── shared/
│       ├── logging.py
│       └── errors.py
└── tests/
```

**Decisões de design**:
- **MQTT worker roda no mesmo processo** do FastAPI via `asyncio` (paho usa thread, conversa por `asyncio.Queue`). Simples e suficiente para milhares de devices. Se escalar > 50k devices → migrar worker para processo separado.
- **Batched insert**: telemetria entra numa fila in-memory; flush a cada 1s ou 500 msgs (o que vier antes) com `COPY` / `executemany`.
- **Idempotência**: PK composta `(device_id, ts)` ignora duplicatas (ON CONFLICT DO NOTHING).
- **Aggregation**: TimescaleDB continuous aggregates se disponível; senão APScheduler com janelas slid.

---

## 10. Estrutura Flutter (feature-first)

```
mobile/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                  # MaterialApp + Riverpod scope
│   │   ├── router.dart               # go_router
│   │   └── theme/                    # tema Vena (paleta, tipo)
│   ├── core/
│   │   ├── db/                       # Drift database, DAOs
│   │   ├── network/                  # Dio client, interceptors JWT
│   │   ├── ble/                      # BleService (reactive_ble wrapper)
│   │   ├── mqtt/                     # MqttService (mqtt_client wrapper)
│   │   ├── auth/                     # Google sign-in + secure storage tokens
│   │   ├── sync/                     # OutboxWorker, conflict resolver
│   │   └── result.dart               # Result<T, Failure>
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/repository.dart
│   │   │   ├── application/ (controllers/providers)
│   │   │   └── presentation/ (screens, widgets)
│   │   ├── pairing/                  # QR scan + BLE provisioning
│   │   ├── devices/                  # lista, alias, claim
│   │   ├── live/                     # tela de detalhe (BLE+MQTT live)
│   │   ├── history/                  # gráficos hora/dia/semana
│   │   └── settings/
│   └── design_system/
│       ├── tokens.dart               # cores, espaçamentos, raios
│       ├── typography.dart
│       ├── components/               # VenaButton, VenaCard, VenaChart, ...
│       └── motion.dart               # durations + curves
└── test/
```

**Gerenciamento de estado (Riverpod)**:
- `latestStateProvider(deviceId)` → `StreamProvider` que escuta Drift (`watchSingle`).
- `bleSessionProvider(deviceId)` → `StateNotifierProvider` controla scan/connect/notify.
- `mqttConnectionProvider` → singleton, depende de `authTokenProvider`.
- `sourceProvider(deviceId)` → computed (último entre BLE e MQTT por ts).

**Lifecycle**:
- `AppLifecycleState.resumed` → reconecta MQTT/BLE; força sync.
- `paused` → mantém conexões por 30s; após isso desconecta.
- `detached` → desliga tudo.

**Estratégia de cache**:
- SQLite é cache de leitura sempre.
- Histórico: ao abrir tela de gráfico, chama backend `GET /history?range=24h&bucket=1m`, armazena em `history_cache` com TTL 5min.
- Drift como única fonte de verdade para UI. Listeners reativos.

**Bibliotecas Flutter recomendadas**:
- `flutter_riverpod`, `riverpod_annotation` (code-gen)
- `drift` + `drift_dev`
- `mqtt_client`
- `flutter_reactive_ble`
- `google_sign_in`
- `dio` + `dio_smart_retry`
- `go_router`
- `fl_chart` (gráficos elegantes)
- `flutter_secure_storage` (JWT)
- `mobile_scanner` (QR code)
- `permission_handler`
- `freezed` + `json_serializable`

---

## 11. Design System Vena

**Identidade visual**:
- Tom orgânico/artesanal. Cantos `radius: 20` (largos), sombras suaves baseadas em `#5f6c37` com 8% alpha.
- Paleta:
  - Primary `#5f6c37` (verde-oliva profundo) — CTAs, ícones ativos
  - Secondary `#768d3b` (verde-folha claro) — destaques, gráficos
  - Background `#f7eddd` (creme) — superfícies
  - Surface alta `#fffbf3`
  - Texto principal `#2b2f1a`
  - Texto secundário `#6c6b5c`
  - Estados: warning `#c98a3b`, danger `#a23c2e`, success `#5f6c37`
- **Tipografia**:
  - Headlines: **Fraunces** (serif moderna, levemente artística) — `weight 500`, tracking -0.5
  - Body/UI: **Inter** ou **DM Sans** — pesos 400/500
  - Números (telemetria): **Inter Tight** ou **Fraunces tabular**
- **Iconografia**: `phosphor_flutter` (linhas finas, peso "duotone" para destaques).
- **Motion**:
  - Durações: 200ms (micro), 350ms (transições), 600ms (entrada de tela)
  - Curves: `Curves.easeOutCubic` padrão; `Curves.easeOutBack` para feedback positivo
  - Sempre animar mudanças de número de telemetria (`AnimatedSwitcher` + `TweenAnimationBuilder`)

**Estilo dos gráficos**:
- Linha única, espessura 2.5, sem grade pesada (apenas eixo Y em 3 ticks).
- Gradiente verde-oliva → transparente abaixo da linha.
- Tooltip ao tocar com card flutuante mostrando T/H + horário.
- Faixas de threshold (futuro) com fill semi-transparente.

**Componentes-chave**:
- `VenaCard` (cantos 20, sombra orgânica, padding 20)
- `MetricTile` (valor grande tabular + label + delta animado)
- `ConnectionBadge` (BLE/MQTT/Offline com micro-animação pulse)
- `DeviceChip` (avatar gerado do device_id em SVG abstrato)

**UX direction**:
- Tela inicial = lista de "minhas Venas" como cards verticais grandes, cada um mostrando T atual + status.
- Tela de detalhe imerssiva: número GIGANTE de temperatura no topo, sub-info abaixo, gráfico de 24h no rodapé.
- Pareamento: wizard em 3 passos com ilustrações artísticas (scan QR → conectar BLE → nomear).
- Vazio é elegante: ilustrações de folhas, copy minimalista ("Aproxime-se de uma Vena para começar").

---

## 12. Infra & Deploy

**Docker Compose inicial (VPS)**:
```yaml
services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    volumes: [pgdata:/var/lib/postgresql/data]
    env_file: .env
  mosquitto:
    image: iegomez/mosquitto-go-auth   # já tem o plugin
    ports: ["1883:1883", "8883:8883", "9001:9001"]  # tcp, tls, ws
    volumes:
      - ./mosquitto/mosquitto.conf:/etc/mosquitto/mosquitto.conf
      - ./mosquitto/certs:/mosquitto/certs
  backend:
    build: ./backend
    env_file: .env
    depends_on: [postgres, mosquitto]
    ports: ["8000:8000"]
  caddy:                              # reverse proxy + TLS auto
    image: caddy:2
    ports: ["80:80", "443:443"]
    volumes: [./Caddyfile:/etc/caddy/Caddyfile, caddy_data:/data]
volumes: { pgdata: {}, caddy_data: {} }
```
- **Caddy** termina TLS para `api.vena.app` (FastAPI) e `mqtt.vena.app:8883` (passthrough TCP) — alternativa: usar certs do Let's Encrypt direto no Mosquitto.
- Backup PostgreSQL: `pg_dump` cron diário p/ S3 ou rsync.
- Observabilidade básica: `loguru` no backend + log driver json-file rotativo. Futuro: Grafana + Loki.

---

## 13. Roadmap de implementação

### Fase 0 — Fundação (semanas 1-2)
1. Criar repositório monorepo: `backend/`, `mobile/`, `firmware/`, `infra/`.
2. Docker Compose com Postgres + Mosquitto **anônimo** rodando local.
3. Backend FastAPI skeleton + Alembic + modelos `User`, `Device`, `UserDevice`.
4. Endpoint `/health` + log estruturado.

### Fase 1 — Telemetria end-to-end mínima (semanas 3-4) *paralelo com Fase 0*
5. **Refactor firmware mínimo**: substituir ID hardcoded por `vena-<mac>`, tópicos para `vena/{id}/telemetry`. **Adiciona NTP** e campos `ts`+`seq`. (BLE ainda não.)
6. Backend MQTT worker: subscribe `vena/+/telemetry`, parse, insert em `telemetry_raw`.
7. Endpoint `GET /devices/{id}/history?range=...` retornando raw.
8. Smoke test: ESP32 publica → Postgres recebe → REST devolve.

### Fase 2 — Auth e identidade (semanas 5-6)
9. Google OAuth no backend + emissão de JWT.
10. Endpoints `/devices/claim` (pairing_code) e `/devices` (listagem por user).
11. `mosquitto-go-auth` configurado, endpoints `/mqtt/auth` `/mqtt/acl`.
12. Backend emite **device JWT** durante provisioning (via endpoint admin temporário).
13. Firmware passa a autenticar no MQTT com JWT.

### Fase 3 — Mobile app monitoramento remoto (semanas 7-9)
14. Scaffold Flutter, theme/design system, go_router, Drift schema.
15. Google sign-in + secure storage de tokens.
16. Listagem de devices + tela de detalhe lendo de SQLite.
17. Integração MQTT: subscribe → grava SQLite → UI reativa.
18. Tela de histórico consumindo REST + cache local.
19. Outbox pattern para alias/rename.

### Fase 4 — BLE (semanas 10-12)
20. Adicionar BLE GATT no firmware (Vena Service com `device_info`, `live_telemetry` notify, `wifi_provisioning`).
21. `BleService` no Flutter com `flutter_reactive_ble`.
22. Tela de pareamento: QR scan → BLE provisioning → claim no backend.
23. Tela de detalhe escutando BLE + MQTT em paralelo; merge por `ts` no SQLite; badge de fonte.
24. Tratamento de permissões Android/iOS.

### Fase 5 — Agregação e produção (semanas 13-14)
25. Continuous aggregates ou APScheduler para `telemetry_1m`, `_1h`, `_1d`.
26. Retention policies.
27. Endpoint `/history` usa bucket apropriado conforme range (24h→1m, 7d→1h, 30d→1d).
28. Deploy VPS com Caddy/TLS.
29. Beta interno: 3-5 unidades Vena reais em campo.

### Fase 6 — Pós-MVP (futuro)
- Push notifications (FCM) ligadas a `device_thresholds`.
- Modo background BLE robusto.
- App admin web (next.js) para suporte.
- Multi-language (PT-BR/EN).
- TimescaleDB hypertables + compression.

---

## 14. Riscos técnicos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| BLE no iOS background (entrega de notify pausa) | Alta | Médio | Usar `restoreIdentifier`; documentar limitação; cair pra MQTT fora do app |
| Conexão MQTT direto do app drena bateria | Média | Médio | Desconecta após 30s em background; reconecta em foreground |
| ESP32 sem NTP envia ts inválido | Alta inicial | Alto (gráficos quebram) | Bloquear publish até NTP sincronizar; usar `seq` como fallback |
| `mosquitto-go-auth` mal configurado abre broker | Média | Crítico | Testes E2E que validam ACL antes de cada deploy |
| TimescaleDB ausente na VPS | Baixa | Médio | Plano B: Postgres puro + APScheduler. Migrar depois |
| DHT22 falha lendo (NaN) | Alta | Baixo | Já tratado no firmware (cache do último válido) — manter |
| App mostra dados velhos como "atuais" | Média | Médio | Sempre exibir `ts` relativo ("há 2min") + badge offline |
| Reflash do ESP perde claim | Baixa | Alto | `pairing_code` é determinístico do MAC+secret; reclaim recria relação |
| Múltiplos apps escutando MQTT do mesmo user | Média | Baixo | Usar `clientId = jwt.sub + uuid`; broker aceita múltiplas sessions |

---

## 15. Guidelines de engenharia

- **Backend**: type hints obrigatórios, `mypy --strict` em CI. Pydantic v2 para tudo que cruza fronteira. Async em todo I/O.
- **Mobile**: `freezed` para todos os modelos. Sem `setState` fora de widgets descartáveis — tudo em Riverpod. `dart fix` + `very_good_analysis` lints.
- **Firmware**: sem `String` em hot path (usa `StaticJsonDocument`). Sempre clampar PWM. NTP obrigatório antes de publicar.
- **Git**: trunk-based, feature branches curtas. Commit messages convencionais (`feat:`, `fix:`).
- **CI**: GitHub Actions — lint + test em PR; build firmware via PlatformIO; build APK em tag.
- **Segurança**: JWT secrets em env var; nunca logar tokens; pairing_codes nunca em log.
- **Observabilidade**: cada publish/subscribe MQTT logado com `device_id` + latência.

---

## 16. Arquivos atuais a modificar/descartar

- `application/` (Python atual) — **refactor estruturado**: vira `backend/app/mqtt/worker.py` + `backend/app/telemetry/ingest.py`. Reaproveita a lógica de parsing JSON de `telemetry_service.py`.
- `publisher.py`, `run.py` — descartar (substituídos pelo `uvicorn app.main:app`).
- `application/configs/broker_configs.py` — descartar; configs migram para `app/config.py` (Pydantic Settings + `.env`).
- `firmware/include/config.h` — manter pinout/PID; substituir bloco MQTT (topics, client_id) por derivação dinâmica do MAC e JWT.
- `firmware/lib/MqttPublisher/` — adicionar JWT auth + TLS. Manter backoff e offline buffer (excelentes).
- `firmware/lib/OfflineBuffer/` — manter; ajustar para serializar `ts`+`seq` reais.
- `firmware/src/main.cpp` — adicionar NTP, dynamic device_id, BLE init (na fase 4).
- `tests/test_offline_flow.py` — adaptar para novo schema de tópicos.

---

## 17. Verificação

1. **Telemetria E2E**: ESP físico ligado, ver 12 amostras chegando em `telemetry_raw` em 60s (frequência 5s).
2. **Offline buffer**: derrubar Wi-Fi 5min, religar; ver gap recuperado em ordem com `seq` contíguos.
3. **MQTT ACL**: token do `user A` tenta `subscribe vena/<deviceB>/+` → broker recusa (logs).
4. **App offline**: avião → abrir app → ver último estado em <1s; gráfico de cache renderiza.
5. **BLE live**: aproximar do device sem Wi-Fi no celular; ver dados atualizando a cada 2s; badge "Local".
6. **BLE + MQTT simultâneo**: badge alterna conforme `ts` mais recente.
7. **Pairing**: scan QR de Vena nova → claim → device aparece remotamente em outro celular logado com mesmo Google account.
8. **Token refresh**: forçar JWT expirar (1min de teste) → app reconecta sem perder mensagens.
9. **Retenção**: rodar agregador, conferir contagem em `_1m` = ~60/h por device; raw mantido 30d.

---

## 18. Considerações futuras (decisões deliberadamente postergadas)

- **OTA firmware** via MQTT (`vena/{id}/cmd/ota` com URL assinada) — após MVP.
- **Edge gateway** (Raspberry Pi local agindo como broker offline na fazenda) — só se feedback mostrar Wi-Fi precária.
- **Multi-tenancy organizacional** (cooperativas com múltiplos produtores) — modelar `organizations` em fase 6.
- **App admin web** para suporte técnico.
- **TimescaleDB compression + tiered storage** quando volume ultrapassar 100M linhas.
