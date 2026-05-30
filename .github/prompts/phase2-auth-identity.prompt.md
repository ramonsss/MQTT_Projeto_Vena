# Fase 2 — Auth, Identidade e Retenção de Dados

> **Objetivo**: Implementar autenticação Google OAuth no backend, emissão de JWT, endpoints de claim/listagem de dispositivos, configurar `mosquitto-go-auth` para ACL baseada em JWT, e adicionar políticas de retenção (hypertable + retention policy) para controlar crescimento do banco.
>
> **Pré-requisito**: Fase 1 concluída (telemetria E2E funcionando — ESP32 publica → worker ingere → REST devolve histórico; testes E1-E4 passando).

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | Provider OAuth | Google (único). Lib: `google-auth` para validar `id_token`. Sem lib de OAuth server — frontend faz OAuth dance, backend só valida o token. |
| 2 | Formato JWT backend | HS256 com secret em `.env`. Claims: `sub` (user uuid), `email`, `exp`, `iat`. Access token: 60min. Refresh token: 30 dias (opaco, armazenado em DB). |
| 3 | Formato JWT MQTT | Mesmo secret HS256. Claims: `sub` (user uuid ou device_id), `scope` ("app"\|"device"\|"backend"), `devices` (lista de device_ids do user), `exp`. TTL: 1h para app, 1 ano para device. |
| 4 | Pairing code | SHA-256(MAC + factory_secret) truncado a 8 chars alfanuméricos uppercase (ex.: `K7X9M2P4`). Factory secret: env var `PAIRING_SECRET`. Backend armazena `bcrypt(pairing_code)` em `devices.pairing_code_hash`. |
| 5 | mosquitto-go-auth | Plugin HTTP mode. Backend expõe `/mqtt/auth` (username=JWT, valida assinatura+exp), `/mqtt/acl` (verifica claim `devices` ⊃ device_id do tópico), `/mqtt/superuser` (nega todos). |
| 6 | Firmware auth (simplificado) | Nesta fase, firmware recebe device JWT via endpoint admin `POST /devices/{id}/provision` e armazena em NVS. Usa como `username` no MQTT connect. BLE provisioning fica para Fase 4. |
| 7 | Retenção `telemetry_raw` | Converter para TimescaleDB hypertable (chunk 1 dia). Retention policy: 90 dias. |
| 8 | Agregação | Continuous aggregate `telemetry_hourly` (avg, min, max por hora). Retention: 2 anos. Continuous aggregate `telemetry_daily`. Retention: indefinido. |
| 9 | Refresh token storage | Tabela `refresh_tokens(id uuid, user_id fk, token_hash text, expires_at, revoked_at, created_at)`. Permite revogar sessões. |
| 10 | CORS | Permitir `http://localhost:*` em dev. Produção: `https://app.vena.farm`. |

---

## Contratos

### REST: `POST /auth/google`

**Request body**:
```json
{
  "id_token": "<Google OAuth id_token>"
}
```

**Response 200**:
```json
{
  "access_token": "<JWT>",
  "refresh_token": "<opaque-uuid>",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "uuid",
    "email": "user@gmail.com"
  }
}
```

**Response 401**: token inválido ou expirado.

---

### REST: `POST /auth/refresh`

**Request body**:
```json
{
  "refresh_token": "<opaque-uuid>"
}
```

**Response 200**: mesmo formato do `/auth/google` (novo access + refresh, refresh antigo revogado).

**Response 401**: refresh token inválido/expirado/revogado.

---

### REST: `POST /devices/{device_id}/claim`

**Headers**: `Authorization: Bearer <access_token>`

**Request body**:
```json
{
  "pairing_code": "K7X9M2P4"
}
```

**Response 200**:
```json
{
  "device_id": "vena-a0b765c1d2e3",
  "alias": null,
  "claimed_at": "2026-05-21T12:00:00Z"
}
```

**Response 404**: device não existe.
**Response 403**: pairing_code inválido.
**Response 409**: device já claimado por este user.

---

### REST: `GET /devices`

**Headers**: `Authorization: Bearer <access_token>`

**Response 200**:
```json
{
  "devices": [
    {
      "device_id": "vena-a0b765c1d2e3",
      "alias": "Vena Estufa 1",
      "status": "online",
      "last_seen_at": "2026-05-21T12:00:00Z",
      "fw_version": "1.1.0"
    }
  ]
}
```

---

### REST: `PATCH /devices/{device_id}`

**Headers**: `Authorization: Bearer <access_token>`

**Request body**:
```json
{
  "alias": "Vena Estufa Norte"
}
```

**Response 200**: device atualizado.
**Response 403**: user não é dono do device.

---

### REST: `POST /mqtt/credentials`

**Headers**: `Authorization: Bearer <access_token>`

**Response 200**:
```json
{
  "mqtt_token": "<JWT MQTT de curta duração>",
  "expires_in": 3600,
  "broker_host": "mqtt.vena.farm",
  "broker_port": 8883
}
```

---

### REST: `POST /devices/{device_id}/provision` (admin)

**Headers**: `Authorization: Bearer <access_token>` (scope admin — no MVP, qualquer user autenticado)

**Response 200**:
```json
{
  "device_jwt": "<JWT MQTT longo-prazo com scope=device>",
  "expires_in": 31536000
}
```

---

### Broker Auth Endpoints (chamados pelo mosquitto-go-auth)

#### `POST /mqtt/auth`
**Form body**: `username=<jwt>&password=&clientid=<clientId>`
**Response**: `200 OK` (auth ok) ou `403` (deny).

#### `POST /mqtt/acl`
**Form body**: `username=<jwt>&topic=vena/xyz/telemetry&clientid=<clientId>&acc=1` (1=sub, 2=pub)
**Response**: `200 OK` (allowed) ou `403` (denied).

#### `POST /mqtt/superuser`
**Form body**: `username=<jwt>`
**Response**: `403` sempre (nenhum superuser via HTTP).

---

## Checklist de implementação

### A. Retenção & Agregação (TimescaleDB)

| # | Arquivo | O que faz |
|---|---------|-----------|
| A1 | Migration `convert_hypertable.py` | `SELECT create_hypertable('telemetry_raw', 'ts', migrate_data => true, chunk_time_interval => INTERVAL '1 day')`. Adiciona retention policy 90 dias. |
| A2 | Migration `create_continuous_aggregates.py` | Cria `telemetry_hourly` (avg, min, max de cada coluna float, group by device_id + time_bucket 1h). Refresh policy: materializa últimas 3h a cada 30min. Retention: 2 anos. |
| A3 | Migration `create_daily_aggregate.py` | Cria `telemetry_daily` (mesmo padrão). Refresh: últimas 2d a cada 6h. Sem retention (indefinido). |

### B. Auth — Models & Infra

| # | Arquivo | O que faz |
|---|---------|-----------|
| B1 | `app/config.py` | Adicionar settings: `google_client_id`, `pairing_secret`, `jwt_refresh_expire_days=30`, `mqtt_jwt_expire_minutes=60`, `device_jwt_expire_days=365`. |
| B2 | `app/db/models.py` | Adicionar model `RefreshToken(id uuid pk, user_id fk, token_hash text, expires_at, revoked_at nullable, created_at)`. |
| B3 | Migration `add_refresh_tokens.py` | `alembic revision --autogenerate -m "add_refresh_tokens"`. |

### C. Auth — Service & Routes

| # | Arquivo | O que faz |
|---|---------|-----------|
| C1 | `app/auth/__init__.py` | Package init. |
| C2 | `app/auth/google.py` | `verify_google_token(id_token: str) -> GoogleUserInfo` — valida com `google.oauth2.id_token.verify_oauth2_token()`. Retorna `sub`, `email`, `name`. |
| C3 | `app/auth/jwt.py` | `create_access_token(user)`, `create_refresh_token(user)`, `create_mqtt_token(user, devices)`, `create_device_jwt(device_id)`, `decode_token(token)`. Usa `python-jose`. |
| C4 | `app/auth/deps.py` | `get_current_user(token: str = Depends(oauth2_scheme)) -> User` — valida JWT, busca user no DB, 401 se inválido. |
| C5 | `app/auth/schemas.py` | Pydantic: `GoogleLoginRequest`, `TokenResponse`, `RefreshRequest`. |
| C6 | `app/auth/service.py` | `login_with_google(id_token)` → verifica Google token → upsert User → gera access+refresh → retorna. `refresh_access_token(refresh_token)` → valida → revoga antigo → emite novos. |
| C7 | `app/auth/routes.py` | `POST /auth/google`, `POST /auth/refresh`. Router prefix `/auth`. |

### D. Devices — Claim & Management

| # | Arquivo | O que faz |
|---|---------|-----------|
| D1 | `app/devices/__init__.py` | Package init. |
| D2 | `app/devices/schemas.py` | Pydantic: `ClaimRequest`, `ClaimResponse`, `DeviceListResponse`, `DeviceItem`, `DeviceUpdateRequest`. |
| D3 | `app/devices/service.py` | `claim_device(user, device_id, pairing_code)` → verifica bcrypt → cria UserDevice → retorna. `list_user_devices(user)` → query join. `update_device_alias(user, device_id, alias)`. |
| D4 | `app/devices/routes.py` | `POST /devices/{id}/claim`, `GET /devices`, `PATCH /devices/{id}`. Todas protegidas com `Depends(get_current_user)`. |
| D5 | `app/devices/pairing.py` | `generate_pairing_code(mac: str) -> str` — SHA-256(mac + PAIRING_SECRET)[:8].upper(). `hash_pairing_code(code) -> str` — bcrypt. `verify_pairing_code(code, hash) -> bool`. |

### E. MQTT Credentials & Broker Auth

| # | Arquivo | O que faz |
|---|---------|-----------|
| E1 | `app/mqtt/credentials.py` | `get_mqtt_credentials(user) -> MqttCredentials` — lista devices do user, gera JWT MQTT com claim `devices`. |
| E2 | `app/mqtt/routes.py` | `POST /mqtt/credentials` (protegido). `POST /devices/{id}/provision` (gera device JWT). |
| E3 | `app/broker_auth/__init__.py` | Package init. |
| E4 | `app/broker_auth/routes.py` | `POST /mqtt/auth` — decodifica JWT do username, verifica exp. `POST /mqtt/acl` — extrai device_id do tópico, verifica ∈ claim `devices` (ou scope=device com device_id match). `POST /mqtt/superuser` → 403 sempre. |
| E5 | `app/broker_auth/schemas.py` | `AuthForm`, `AclForm` (pydantic `Form` models). |

### F. Integração & Wiring

| # | Arquivo | O que faz |
|---|---------|-----------|
| F1 | `app/main.py` | Registrar routers: `auth_router`, `devices_router`, `mqtt_routes`, `broker_auth_router`. Adicionar CORSMiddleware. |
| F2 | `.env` | Adicionar `GOOGLE_CLIENT_ID`, `PAIRING_SECRET`, `MQTT_JWT_SECRET` (pode ser o mesmo que JWT_SECRET em dev). |
| F3 | `infra/mosquitto/mosquitto.conf` | Configurar `mosquitto-go-auth` plugin HTTP apontando para `http://backend:8000/mqtt/auth`, `/mqtt/acl`, `/mqtt/superuser`. |

### G. Firmware — MQTT Auth

| # | Arquivo | O que faz |
|---|---------|-----------|
| G1 | `config.h` | Adicionar `MQTT_USE_AUTH` flag (default 0 em dev). |
| G2 | `MqttPublisher.cpp` | Se `MQTT_USE_AUTH`: `_mqtt.setCredentials(deviceJwt, "")` antes de `connect()`. |
| G3 | NVS storage | Adicionar funções `nvs_store_jwt(token)` e `nvs_load_jwt() -> String`. Firmware tenta carregar do NVS no boot; se vazio, opera sem auth (dev mode). |

### H. Testes

| # | O que valida |
|---|---|
| H1 | `POST /auth/google` com token mockado → retorna access + refresh + user criado no DB. |
| H2 | `POST /auth/refresh` com refresh válido → novo par de tokens. Refresh antigo revogado. |
| H3 | `POST /auth/refresh` com token revogado → 401. |
| H4 | `POST /devices/{id}/claim` com pairing_code correto → UserDevice criado. |
| H5 | `POST /devices/{id}/claim` com pairing_code errado → 403. |
| H6 | `GET /devices` → retorna apenas devices do user autenticado. |
| H7 | `POST /mqtt/auth` com JWT válido → 200; expirado → 403. |
| H8 | `POST /mqtt/acl` com device ∈ claim → 200; device ∉ claim → 403. |
| H9 | Verificar que `telemetry_raw` é hypertable: `SELECT * FROM timescaledb_information.hypertables WHERE hypertable_name = 'telemetry_raw'`. |
| H10 | Verificar retention policy ativa: `SELECT * FROM timescaledb_information.jobs WHERE hypertable_name = 'telemetry_raw'`. |

---

## Modelo SQLAlchemy: `RefreshToken`

```python
class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(Text, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship()
```

---

## Migrations SQL: TimescaleDB Hypertable & Retenção

### A1 — Converter `telemetry_raw` em hypertable

```sql
-- Requer extensão ativa (já presente no timescale/timescaledb image)
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Converter tabela existente (migrate_data copia rows para chunks)
SELECT create_hypertable(
    'telemetry_raw',
    'ts',
    migrate_data => true,
    chunk_time_interval => INTERVAL '1 day'
);

-- Política de retenção: apagar chunks > 90 dias automaticamente
SELECT add_retention_policy('telemetry_raw', INTERVAL '90 days');
```

### A2 — Continuous aggregate: `telemetry_hourly`

```sql
CREATE MATERIALIZED VIEW telemetry_hourly
WITH (timescaledb.continuous) AS
SELECT
    device_id,
    time_bucket('1 hour', ts) AS bucket,
    AVG(ambient_t)  AS ambient_t_avg,
    MIN(ambient_t)  AS ambient_t_min,
    MAX(ambient_t)  AS ambient_t_max,
    AVG(ambient_h)  AS ambient_h_avg,
    MIN(ambient_h)  AS ambient_h_min,
    MAX(ambient_h)  AS ambient_h_max,
    AVG(diss_t)     AS diss_t_avg,
    MIN(diss_t)     AS diss_t_min,
    MAX(diss_t)     AS diss_t_max,
    AVG(diss_h)     AS diss_h_avg,
    MIN(diss_h)     AS diss_h_min,
    MAX(diss_h)     AS diss_h_max,
    AVG(setpoint)   AS setpoint_avg,
    AVG(pid_out)    AS pid_out_avg,
    COUNT(*)        AS sample_count
FROM telemetry_raw
GROUP BY device_id, bucket
WITH NO DATA;

-- Refresh automático: materializa últimas 3h a cada 30 minutos
SELECT add_continuous_aggregate_policy('telemetry_hourly',
    start_offset    => INTERVAL '3 hours',
    end_offset      => INTERVAL '30 minutes',
    schedule_interval => INTERVAL '30 minutes'
);

-- Retenção do agregado horário: 2 anos
SELECT add_retention_policy('telemetry_hourly', INTERVAL '2 years');
```

### A3 — Continuous aggregate: `telemetry_daily`

```sql
CREATE MATERIALIZED VIEW telemetry_daily
WITH (timescaledb.continuous) AS
SELECT
    device_id,
    time_bucket('1 day', ts) AS bucket,
    AVG(ambient_t)  AS ambient_t_avg,
    MIN(ambient_t)  AS ambient_t_min,
    MAX(ambient_t)  AS ambient_t_max,
    AVG(ambient_h)  AS ambient_h_avg,
    MIN(ambient_h)  AS ambient_h_min,
    MAX(ambient_h)  AS ambient_h_max,
    AVG(diss_t)     AS diss_t_avg,
    MIN(diss_t)     AS diss_t_min,
    MAX(diss_t)     AS diss_t_max,
    AVG(diss_h)     AS diss_h_avg,
    MIN(diss_h)     AS diss_h_min,
    MAX(diss_h)     AS diss_h_max,
    AVG(setpoint)   AS setpoint_avg,
    AVG(pid_out)    AS pid_out_avg,
    COUNT(*)        AS sample_count
FROM telemetry_raw
GROUP BY device_id, bucket
WITH NO DATA;

-- Refresh: últimas 2 dias a cada 6 horas
SELECT add_continuous_aggregate_policy('telemetry_daily',
    start_offset    => INTERVAL '2 days',
    end_offset      => INTERVAL '6 hours',
    schedule_interval => INTERVAL '6 hours'
);

-- Sem retention policy (manter indefinidamente)
```

---

## Fluxo de Auth — Diagrama

```
┌─────────┐        ┌─────────────┐         ┌──────────────────┐
│  App    │        │  Backend    │         │  Google OAuth    │
└────┬────┘        └──────┬──────┘         └────────┬─────────┘
     │  1. Google Sign-In │                         │
     │─────────────────────────────────────────────▶│
     │  2. id_token       │                         │
     │◀─────────────────────────────────────────────│
     │                    │                         │
     │  3. POST /auth/google {id_token}             │
     │───────────────────▶│                         │
     │                    │  4. verify_oauth2_token  │
     │                    │────────────────────────▶│
     │                    │  5. {sub, email}         │
     │                    │◀────────────────────────│
     │                    │  6. upsert User + emit JWT
     │  7. {access, refresh, user}                  │
     │◀───────────────────│                         │
     │                    │                         │
     │  8. POST /mqtt/credentials                   │
     │───────────────────▶│                         │
     │                    │  9. list user devices    │
     │                    │  10. sign mqtt_jwt       │
     │  11. {mqtt_token, broker_host}               │
     │◀───────────────────│                         │
     │                    │                         │
     │  12. MQTT connect(username=mqtt_jwt)          │
     │──────────────────────────────▶ Mosquitto     │
     │                    │          │ 13. POST /mqtt/auth
     │                    │◀─────────│              │
     │                    │  14. 200 │              │
     │                    │─────────▶│              │
```

---

## Fluxo de Claim — Diagrama

```
┌─────────┐         ┌──────────┐         ┌──────────┐
│  App    │         │ Backend  │         │ Postgres │
└────┬────┘         └─────┬────┘         └─────┬────┘
     │                    │                    │
     │ 1. Scan QR → extrai pairing_code       │
     │ 2. POST /devices/{id}/claim             │
     │      {pairing_code}                     │
     │───────────────────▶│                    │
     │                    │ 3. SELECT device   │
     │                    │───────────────────▶│
     │                    │ 4. device row      │
     │                    │◀───────────────────│
     │                    │                    │
     │                    │ 5. bcrypt.verify(code, hash)
     │                    │  → match?          │
     │                    │                    │
     │                    │ 6. INSERT user_devices
     │                    │───────────────────▶│
     │                    │ 7. ok              │
     │                    │◀───────────────────│
     │  8. 200 {claimed}  │                    │
     │◀───────────────────│                    │
```

---

## Configuração mosquitto-go-auth

```conf
# mosquitto.conf (trecho relevante)
listener 1883
protocol mqtt

# Anonymous OFF quando auth ativado
allow_anonymous false

# Plugin
plugin /mosquitto/go-auth.so
auth_plugin_deny_special_chars true

# HTTP backend
auth_opt_backends http
auth_opt_http_host backend
auth_opt_http_port 8000
auth_opt_http_getuser_uri /mqtt/auth
auth_opt_http_aclcheck_uri /mqtt/acl
auth_opt_http_superuser_uri /mqtt/superuser
auth_opt_http_method POST
auth_opt_http_params_mode form
auth_opt_http_timeout 5

# Cache para não bater no backend a cada msg
auth_opt_cache true
auth_opt_cache_type go-cache
auth_opt_cache_reset true
auth_opt_auth_cache_seconds 300
auth_opt_acl_cache_seconds 300
```

---

## Critérios de aceite (DoD)

| # | Critério | Como verificar |
|---|----------|----------------|
| 1 | Login com Google retorna JWT válido | `POST /auth/google` com id_token mockado → 200 + token decodifica corretamente |
| 2 | Refresh token funciona | Usar refresh → novo access token valida |
| 3 | Refresh token revogado é rejeitado | Usar mesmo refresh 2x → segundo retorna 401 |
| 4 | Claim com pairing_code correto | Device aparece em `GET /devices` do user |
| 5 | Claim com pairing_code errado | Retorna 403, nenhum UserDevice criado |
| 6 | MQTT credentials emite JWT com devices | Decodificar JWT → claim `devices` contém lista correta |
| 7 | Broker auth valida JWT | `mosquitto_pub -u <jwt_valido>` → aceita; `-u <jwt_expirado>` → rejeita |
| 8 | Broker ACL funciona | User subscribed a device que não é seu → broker desconecta |
| 9 | Hypertable criada | `SELECT * FROM timescaledb_information.hypertables` → `telemetry_raw` listada |
| 10 | Retention policy ativa | `SELECT * FROM timescaledb_information.jobs WHERE proc_name = 'policy_retention'` → 90 days para raw |
| 11 | Continuous aggregate popula | Inserir dados > 1h atrás → `SELECT * FROM telemetry_hourly` retorna linhas |
| 12 | Device JWT funciona no firmware | ESP32 com JWT no NVS conecta ao broker autenticado |

---

## Armadilhas conhecidas

| Problema | Solução |
|----------|---------|
| `create_hypertable` falha se tabela tem FK de outra tabela apontando para ela | `telemetry_raw` tem FK `→ devices`. Hypertable aceita FK de child para parent, mas NÃO de parent para child. Nosso caso é ok (child aponta para parent). |
| `create_hypertable` com `migrate_data` em tabela grande pode demorar | Aceitável — tabela tem < 100k rows na Fase 1. Executar em horário de baixo uso. |
| `google-auth` precisa de `GOOGLE_CLIENT_ID` para validar `aud` claim | Configurar no `.env`. Em testes, mockar a função de verificação. |
| `mosquitto-go-auth` imagem Docker diferente da `eclipse-mosquitto` | Mudar para `iegomez/mosquitto-go-auth` no docker-compose. Ou compilar plugin separado. |
| JWT MQTT expira enquanto app está conectado | App renova 5min antes do `exp` e reconecta. Broker mantém sessão até próximo PINGREQ. |
| `bcrypt` é lento (~250ms por verify) | Aceitável para claim (operação rara). Não usar em hot path. |
| Alembic não suporta `SELECT create_hypertable(...)` nativamente | Usar `op.execute()` com SQL raw na migration. Marcar como não-reversível (`def downgrade(): raise NotImplementedError`). |
| Continuous aggregate não vê dados inseridos antes da criação | Usar `WITH NO DATA` + refresh manual inicial: `CALL refresh_continuous_aggregate('telemetry_hourly', NULL, NULL)`. |
| Firmware sem Wi-Fi não consegue validar JWT (é offline) | JWT é verificado apenas pelo broker. Firmware só armazena e envia. Se JWT expirar offline, reconexão falhará → firmware tenta sem auth (fallback dev) ou aguarda re-provisioning. |

---

## Ordem de execução recomendada

```
 1. [Backend]  A1: Migration — hypertable + retention policy
 2. [Backend]  A2-A3: Migrations — continuous aggregates (hourly + daily)
 3. [Backend]  B1-B3: Config + RefreshToken model + migration
 4. [Backend]  C1-C3: Auth package — google.py + jwt.py
 5. [Backend]  C4-C6: Auth deps + service + schemas
 6. [Backend]  C7: Auth routes (POST /auth/google, /auth/refresh)
 7. [Backend]  D1-D5: Devices package — claim, list, alias, pairing
 8. [Backend]  E1-E2: MQTT credentials + provision routes
 9. [Backend]  E3-E5: Broker auth endpoints (/mqtt/auth, /mqtt/acl)
10. [Backend]  F1-F2: Wiring (main.py routers + .env)
11. [Infra]    F3: mosquitto.conf com mosquitto-go-auth
12. [Backend]  H1-H10: Testes de integração
13. [Firmware] G1-G3: MQTT auth no firmware (NVS + setCredentials)
14. [E2E]     Smoke test completo: firmware com JWT → broker autentica → telemetria persiste
```

---

## Métricas de sucesso (smoke test final)

1. App (simulado via curl/httpx) faz login Google → obtém access token → lista devices (vazio).
2. `POST /devices/vena-xxx/claim` com pairing_code correto → device aparece em `GET /devices`.
3. `POST /mqtt/credentials` → retorna JWT MQTT com claim `devices: ["vena-xxx"]`.
4. `mosquitto_pub -u <mqtt_jwt> -t vena/vena-xxx/telemetry -m '{...}'` → aceita.
5. `mosquitto_pub -u <mqtt_jwt> -t vena/outro-device/telemetry -m '{...}'` → rejeita (ACL).
6. `SELECT * FROM timescaledb_information.hypertables` → `telemetry_raw` é hypertable.
7. ESP32 com device JWT no NVS conecta ao broker com `allow_anonymous false` → telemetria flui.
8. Após 90+ dias simulados (ou `SELECT drop_chunks(...)` manual), dados antigos desaparecem de `telemetry_raw` mas existem em `telemetry_hourly`.

---

## Dependências a instalar

```
# Backend (adicionar ao pyproject.toml)
google-auth>=2.29        # validar id_token Google
bcrypt>=4.2              # hash pairing_code (já instalado)
python-jose[cryptography]>=3.3  # JWT (já instalado)

# Docker (mudar imagem mosquitto)
iegomez/mosquitto-go-auth:latest  # ou build custom com plugin
```
