# Fase 3 — Mobile App: Monitoramento Remoto (Flutter)

> **Objetivo**: Criar o app Flutter com autenticação Google, listagem de dispositivos do usuário, monitoramento em tempo real via MQTT (subscribe → SQLite → UI reativa), e tela de histórico consumindo a REST API do backend. Estrutura offline-first com Drift/SQLite como fonte única da UI.
>
> **Pré-requisito**: Fase 2 concluída (auth Google OAuth + JWT no backend, claim de dispositivos, MQTT broker autenticado com mosquitto-go-auth, smoke test passando, todos os endpoints REST funcionando).

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | State management | Riverpod 2 com `@riverpod` code-gen. Sem `setState` fora de widgets descartáveis triviais. |
| 2 | Navegação | `go_router` com shell route para bottom nav. Deep links preparados. |
| 3 | Banco local | Drift (SQLite) com esquema versionado. DAOs por feature. |
| 4 | MQTT lib | `mqtt_client` (Dart) via TCP porta 1883 em dev, TLS 8883 em prod. |
| 5 | HTTP client | `dio` + interceptor de JWT (attach `Authorization` header, refresh automático em 401). |
| 6 | Armazenamento seguro | `flutter_secure_storage` para tokens (access, refresh, mqtt_jwt). |
| 7 | Google Sign-In | `google_sign_in` plugin → envia `id_token` para `POST /auth/google` do backend. |
| 8 | Gráficos | `fl_chart` com estilo orgânico (gradiente, cantos suaves, eixos minimalistas). |
| 9 | Design system | Paleta Vena (primary `#5f6c37`, background `#f7eddd`), tipografia Fraunces + Inter, corners 20px. |
| 10 | Offline-first | UI lê exclusivamente do Drift. MQTT/REST alimentam o banco. Nunca acessa rede diretamente da UI. |
| 11 | MQTT lifecycle | Conecta ao entrar em foreground; desconecta 30s após ir para background. Renova JWT 5min antes do `exp`. |
| 12 | Outbox | Tabela `outbox` no Drift para operações de escrita (rename alias). Worker tenta sync; backend resolve conflitos. |

---

## Contratos (consumidos pelo app)

### Backend REST (já implementados na Fase 2)

| Endpoint | Método | Uso no app |
|---|---|---|
| `/auth/google` | POST | Login — envia `id_token` do Google |
| `/auth/refresh` | POST | Refresh token rotation |
| `/devices` | GET | Lista de devices do user |
| `/devices/{id}/claim` | POST | Claim após QR scan |
| `/devices/{id}` | PATCH | Renomear alias |
| `/mqtt/credentials` | POST | Obter JWT MQTT de curta duração |
| `/devices/{id}/history` | GET | Dados de telemetria para gráficos |

### MQTT Topics (subscribe)

| Tópico | Conteúdo | Uso |
|---|---|---|
| `vena/{deviceId}/telemetry` | JSON com ts, ambient_t, ambient_h, diss_t, diss_h, setpoint, pid_out | Feed de dados em tempo real |
| `vena/{deviceId}/status` | `{"online": true/false, "fw_version": "..."}` | Status online/offline com retain |

---

## Checklist de implementação

### A. Scaffold & Infraestrutura

| # | Arquivo/Pasta | O que faz |
|---|---|---|
| A1 | `mobile/` (Flutter project) | `flutter create --org farm.vena --project-name vena_app mobile`. Mínimo SDK: Flutter 3.22+, Dart 3.4+. |
| A2 | `mobile/pubspec.yaml` | Dependências: `flutter_riverpod`, `riverpod_annotation`, `go_router`, `drift`, `sqlite3_flutter_libs`, `mqtt_client`, `dio`, `google_sign_in`, `flutter_secure_storage`, `fl_chart`, `freezed`, `json_serializable`, `mobile_scanner`, `phosphor_flutter`, `intl`. Dev deps: `riverpod_generator`, `build_runner`, `drift_dev`, `freezed_annotation`, `json_annotation`. |
| A3 | `mobile/lib/main.dart` | Entry point: `ProviderScope` → `VenaApp`. |
| A4 | `mobile/lib/app/app.dart` | `MaterialApp.router` com `goRouter`, tema Vena. |
| A5 | `mobile/lib/app/router.dart` | `GoRouter` com rotas: `/login`, `/devices` (shell com bottom nav), `/devices/:id` (detalhe), `/devices/:id/history`, `/pair`. Redirect se não autenticado. |
| A6 | `mobile/lib/app/theme/` | `vena_theme.dart` (ThemeData completo), `vena_colors.dart`, `vena_typography.dart`. |

### B. Design System & Componentes

| # | Arquivo | O que faz |
|---|---|---|
| B1 | `mobile/lib/design_system/tokens.dart` | Constantes: cores, espaçamentos (4/8/12/16/20/24/32), raios (8/12/16/20), sombras. |
| B2 | `mobile/lib/design_system/typography.dart` | TextStyles usando Fraunces (headlines) + Inter (body). |
| B3 | `mobile/lib/design_system/components/vena_card.dart` | Card com cantos 20, sombra orgânica, padding 20. |
| B4 | `mobile/lib/design_system/components/metric_tile.dart` | Valor grande (tabular) + label + delta animado + unidade. |
| B5 | `mobile/lib/design_system/components/connection_badge.dart` | Badge MQTT/Offline com ícone + cor + micro-animação pulse. |
| B6 | `mobile/lib/design_system/components/vena_button.dart` | Botão primário/secundário com estados e feedback haptic. |
| B7 | `mobile/lib/design_system/components/empty_state.dart` | Ilustração + texto para listas vazias ("Nenhuma Vena pareada"). |

### C. Core — Banco Local (Drift)

| # | Arquivo | O que faz |
|---|---|---|
| C1 | `mobile/lib/core/db/app_database.dart` | Classe `AppDatabase extends _$AppDatabase`. Schema version 1. |
| C2 | `mobile/lib/core/db/tables/devices_table.dart` | Tabela `devices`: deviceId (PK text), alias, status, lastSeenAt, fwVersion, capabilities. |
| C3 | `mobile/lib/core/db/tables/latest_states_table.dart` | Tabela `latest_states`: deviceId (PK), ts, ambientT, ambientH, dissT, dissH, setpoint, pidOut, source, online. |
| C4 | `mobile/lib/core/db/tables/telemetry_cache_table.dart` | Tabela `telemetry_cache`: (deviceId, ts) PK, ambientT, ambientH, dissT, dissH. Ring buffer: max 1000 por device. |
| C5 | `mobile/lib/core/db/tables/outbox_table.dart` | Tabela `outbox`: id (autoIncrement), action, payload (JSON text), createdAt, synced (bool). |
| C6 | `mobile/lib/core/db/tables/user_session_table.dart` | Tabela `user_session`: key (PK text), value (text). Armazena metadata não-sensitiva (email, userId). Tokens vão no SecureStorage. |
| C7 | `mobile/lib/core/db/daos/device_dao.dart` | DAO: `watchAllDevices()`, `upsertDevice()`, `updateAlias()`. |
| C8 | `mobile/lib/core/db/daos/telemetry_dao.dart` | DAO: `watchLatestState(deviceId)`, `upsertLatestState()`, `insertTelemetryCache()`, `getRecentCache(deviceId, limit)`, `pruneOldEntries(deviceId, keepCount)`. |
| C9 | `mobile/lib/core/db/daos/outbox_dao.dart` | DAO: `insertAction()`, `watchPending()`, `markSynced(id)`. |

### D. Core — Auth

| # | Arquivo | O que faz |
|---|---|---|
| D1 | `mobile/lib/core/auth/auth_repository.dart` | `signInWithGoogle()` → Google Sign-In → envia id_token ao backend → armazena tokens no SecureStorage → retorna `UserInfo`. `refreshToken()` → POST /auth/refresh → atualiza tokens. `signOut()` → limpa storage + Google sign out. |
| D2 | `mobile/lib/core/auth/auth_interceptor.dart` | Dio interceptor: attach `Authorization: Bearer <access_token>`. Em 401: tenta refresh; se falhar, logout. |
| D3 | `mobile/lib/core/auth/auth_provider.dart` | `authStateProvider` (StreamProvider): emite `authenticated/unauthenticated`. `goRouter` depende disso para redirect. |
| D4 | `mobile/lib/core/auth/secure_token_storage.dart` | Wrapper de `flutter_secure_storage`: `saveTokens(access, refresh)`, `getAccessToken()`, `getRefreshToken()`, `clear()`. |

### E. Core — Network (Dio)

| # | Arquivo | O que faz |
|---|---|---|
| E1 | `mobile/lib/core/network/api_client.dart` | Singleton Dio configurado: baseUrl (env), timeout 15s, interceptors (auth, logging). |
| E2 | `mobile/lib/core/network/device_api.dart` | `listDevices()`, `claimDevice(id, code)`, `updateAlias(id, alias)`, `getHistory(id, start, end, limit)`. |
| E3 | `mobile/lib/core/network/mqtt_api.dart` | `getMqttCredentials() → MqttCredentials` (token + host + port + expiresIn). |

### F. Core — MQTT Service

| # | Arquivo | O que faz |
|---|---|---|
| F1 | `mobile/lib/core/mqtt/mqtt_service.dart` | Classe `MqttService`: connect(jwt), disconnect(), subscribe(deviceIds), onMessage stream. Gerencia lifecycle: backoff reconexão, refresh JWT 5min antes de `exp`. |
| F2 | `mobile/lib/core/mqtt/mqtt_provider.dart` | `mqttServiceProvider`: singleton instanciado após login. `mqttConnectionStateProvider`: stream de estado (connected/disconnected/reconnecting). |
| F3 | `mobile/lib/core/mqtt/mqtt_message_handler.dart` | Recebe mensagens MQTT → parse JSON → route por tipo (telemetry → upsert latest_state + insert cache; status → update device online/offline). |
| F4 | `mobile/lib/core/mqtt/mqtt_lifecycle.dart` | Mixin/listener de `AppLifecycleState`: `resumed` → reconnect; `paused` → timer 30s → disconnect. |

### G. Core — Sync (Outbox)

| # | Arquivo | O que faz |
|---|---|---|
| G1 | `mobile/lib/core/sync/outbox_worker.dart` | Observa `outbox` (Drift stream). Para cada entry pendente: executa HTTP call → marca `synced=true` em sucesso; em erro de rede, retry com backoff; em 409, aplica resolução (server wins). |
| G2 | `mobile/lib/core/sync/device_sync_service.dart` | `syncDeviceList()`: chama `GET /devices` → upsert local Drift table. Chamado no login e em pull-to-refresh. |

### H. Feature — Auth (Screens)

| # | Arquivo | O que faz |
|---|---|---|
| H1 | `mobile/lib/features/auth/presentation/login_screen.dart` | Tela de login: logo Vena + botão "Entrar com Google" estilo orgânico. Chama `authRepository.signInWithGoogle()`. |
| H2 | `mobile/lib/features/auth/presentation/splash_screen.dart` | Splash: verifica tokens existentes → navega para `/devices` ou `/login`. |

### I. Feature — Devices (Lista)

| # | Arquivo | O que faz |
|---|---|---|
| I1 | `mobile/lib/features/devices/presentation/devices_screen.dart` | Lista de "Minhas Venas" como cards grandes verticais. Cada card: alias/deviceId, temp atual, status badge. Pull-to-refresh → sync backend. FAB para parear novo. |
| I2 | `mobile/lib/features/devices/presentation/device_card.dart` | Widget extraído: `VenaCard` contendo `MetricTile` (temp) + `ConnectionBadge` + alias. |
| I3 | `mobile/lib/features/devices/application/devices_provider.dart` | `devicesProvider`: `StreamProvider` que faz `watchAllDevices()` do Drift DAO. Combina com `latestStateProvider` para enriquecer com dados live. |
| I4 | `mobile/lib/features/devices/application/device_actions_provider.dart` | Ações: `claimDevice(id, code)` (outbox + sync), `renameDevice(id, alias)` (outbox + local update imediato). |

### J. Feature — Device Detail (Live)

| # | Arquivo | O que faz |
|---|---|---|
| J1 | `mobile/lib/features/live/presentation/device_detail_screen.dart` | Tela imersiva: número GIGANTE de temperatura no topo, sub-métricas (humidity, setpoint, PID output) abaixo, mini-gráfico 1h no rodapé. Badge de conexão. |
| J2 | `mobile/lib/features/live/presentation/widgets/big_metric.dart` | Widget: valor animado (AnimatedSwitcher + TweenAnimationBuilder) com unidade e label. |
| J3 | `mobile/lib/features/live/presentation/widgets/mini_chart.dart` | `fl_chart` LineChart com gradiente, últimas 60 amostras do `telemetry_cache`. |
| J4 | `mobile/lib/features/live/application/live_telemetry_provider.dart` | `latestStateProvider(deviceId)`: StreamProvider do Drift. `recentCacheProvider(deviceId)`: últimas 60 amostras para mini-chart. |

### K. Feature — History

| # | Arquivo | O que faz |
|---|---|---|
| K1 | `mobile/lib/features/history/presentation/history_screen.dart` | Tela de gráfico full com seletor de range (24h/7d/30d). Gráfico `fl_chart` responsivo. Tooltip ao tocar. |
| K2 | `mobile/lib/features/history/application/history_provider.dart` | `historyProvider(deviceId, range)`: FutureProvider que chama `GET /devices/{id}/history` → cacheia em memória por 5min. |
| K3 | `mobile/lib/features/history/presentation/widgets/history_chart.dart` | LineChart configurado com gradiente, eixos minimalistas, faixas de threshold (futuro). |

### L. Feature — Pairing

| # | Arquivo | O que faz |
|---|---|---|
| L1 | `mobile/lib/features/pairing/presentation/pair_screen.dart` | Wizard 3 passos: (1) Scan QR code com `mobile_scanner`, (2) Confirmar device_id + pairing_code extraídos, (3) Nomear (alias). Chama claim endpoint. |
| L2 | `mobile/lib/features/pairing/application/pairing_provider.dart` | `pairingProvider`: gerencia o fluxo — parse QR → POST /claim → success/error. |

---

## Esquema Drift (DDL conceitual)

```dart
// devices
class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get alias => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('offline'))();
  IntColumn get lastSeenAt => integer().nullable()();
  TextColumn get fwVersion => text().nullable()();
  @override
  Set<Column> get primaryKey => {deviceId};
}

// latest_states — 1 row per device, overwritten on each new reading
class LatestStates extends Table {
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real().nullable()();
  RealColumn get ambientH => real().nullable()();
  RealColumn get dissT => real().nullable()();
  RealColumn get dissH => real().nullable()();
  RealColumn get setpoint => real().nullable()();
  RealColumn get pidOut => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('mqtt'))();
  BoolColumn get online => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {deviceId};
}

// telemetry_cache — ring buffer for mini-charts (max ~1000 per device)
class TelemetryCache extends Table {
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real().nullable()();
  RealColumn get ambientH => real().nullable()();
  RealColumn get dissT => real().nullable()();
  RealColumn get dissH => real().nullable()();
  @override
  Set<Column> get primaryKey => {deviceId, ts};
}

// outbox — pending writes to backend
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();           // "claim", "rename"
  TextColumn get payload => text()();          // JSON
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
```

---

## Fluxo MQTT no App — Diagrama

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter App                                                  │
│                                                              │
│  ┌────────────────┐         ┌───────────────────────┐       │
│  │ MqttService    │◀─msg──▶│ MqttMessageHandler     │       │
│  │  - connect(jwt)│         │  - parseTelemetry()    │       │
│  │  - subscribe() │         │  - parseStatus()       │       │
│  │  - reconnect   │         │  - upsert Drift DB     │       │
│  └───────┬────────┘         └───────────┬───────────┘       │
│          │                              │                    │
│          │ JWT refresh                  ▼                    │
│          ▼                    ┌──────────────────┐           │
│  ┌──────────────┐            │  Drift/SQLite    │           │
│  │ Backend API  │◀──REST───▶│  (source of truth)│           │
│  │ /mqtt/creds  │            │                  │           │
│  │ /devices     │            └────────┬─────────┘           │
│  │ /history     │                     │                      │
│  └──────────────┘                     ▼                      │
│                              ┌──────────────────┐           │
│                              │  Riverpod Stream │           │
│                              │  Providers       │           │
│                              └────────┬─────────┘           │
│                                       ▼                      │
│                              ┌──────────────────┐           │
│                              │       UI         │           │
│                              └──────────────────┘           │
└──────────────────────────────────────────────────────────────┘
```

---

## Fluxo de Login — Diagrama

```
┌───────┐         ┌────────────┐         ┌──────────┐        ┌────────┐
│  App  │         │ Google SDK │         │ Backend  │        │ Broker │
└───┬───┘         └─────┬──────┘         └────┬─────┘        └───┬────┘
    │ 1. Tap "Google"   │                     │                   │
    │──────────────────▶│                     │                   │
    │ 2. OAuth flow     │                     │                   │
    │◀──────────────────│                     │                   │
    │ 3. id_token       │                     │                   │
    │                    │                     │                   │
    │ 4. POST /auth/google {id_token}         │                   │
    │─────────────────────────────────────────▶│                   │
    │ 5. {access_token, refresh_token, user}   │                   │
    │◀─────────────────────────────────────────│                   │
    │                                          │                   │
    │ 6. SecureStorage.save(tokens)            │                   │
    │ 7. POST /mqtt/credentials                │                   │
    │─────────────────────────────────────────▶│                   │
    │ 8. {mqtt_token, broker_host, port}       │                   │
    │◀─────────────────────────────────────────│                   │
    │                                          │                   │
    │ 9. MQTT connect(username=mqtt_jwt, password=vena)            │
    │──────────────────────────────────────────────────────────────▶│
    │ 10. CONNACK OK                                                │
    │◀──────────────────────────────────────────────────────────────│
    │                                          │                   │
    │ 11. GET /devices                         │                   │
    │─────────────────────────────────────────▶│                   │
    │ 12. {devices: [...]}                     │                   │
    │◀─────────────────────────────────────────│                   │
    │ 13. Drift.upsertDevices()                │                   │
    │ 14. Navigate → /devices screen           │                   │
```

---

## Configuração Ambiente

### Variáveis de build (flavor dev vs prod)

```dart
// lib/core/env.dart
abstract class Env {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000',  // Android emulator → host
  );
  static const mqttHost = String.fromEnvironment(
    'MQTT_HOST',
    defaultValue: '10.0.2.2',
  );
  static const mqttPort = int.fromEnvironment(
    'MQTT_PORT',
    defaultValue: 1883,
  );
  static const useTls = bool.fromEnvironment(
    'MQTT_TLS',
    defaultValue: false,
  );
}
```

**Build commands**:
```bash
# Dev (emulator, no TLS)
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8000 --dart-define=MQTT_HOST=10.0.2.2

# Prod
flutter run --release --dart-define=BACKEND_URL=https://api.vena.farm --dart-define=MQTT_HOST=mqtt.vena.farm --dart-define=MQTT_PORT=8883 --dart-define=MQTT_TLS=true
```

---

## Testes

| # | O que valida |
|---|---|
| T1 | `AuthRepository.signInWithGoogle()` — mock Google Sign-In + mock backend → tokens armazenados no SecureStorage. |
| T2 | `AuthInterceptor` — request recebe header; em 401, refresh é chamado; em refresh falho, logout. |
| T3 | `MqttService` — connect com JWT válido; subscribe a topics corretos; parse de mensagem telemetry grava no DAO. |
| T4 | `MqttMessageHandler` — JSON telemetry → upsert `latest_states` + insert `telemetry_cache`. Status → update `devices.online`. |
| T5 | `DeviceDao.watchAllDevices()` — stream emite após insert/update. |
| T6 | `TelemetryDao.pruneOldEntries()` — mantém apenas últimos N registros por device. |
| T7 | `OutboxWorker` — entry pendente → HTTP call mockado → marcada como synced; em erro 409 → item removido (server wins). |
| T8 | `HistoryProvider` — chama API com range correto; cacheia resultado; re-fetch após TTL expirar. |
| T9 | Widget test: `DeviceDetailScreen` — exibe valor de `latestState` e atualiza ao receber novo valor do stream. |
| T10 | Integration: login → sync devices → subscribe MQTT → receive telemetry → UI shows live value. (Flutter integration test com mocks.) |

---

## Critérios de aceite (DoD)

| # | Critério | Como verificar |
|---|----------|----------------|
| 1 | Login com Google funciona | Tap botão → backend retorna tokens → app navega para `/devices` |
| 2 | Lista de devices vem do backend | Após login, `GET /devices` → Drift → UI mostra cards |
| 3 | MQTT conecta com JWT | Logs mostram CONNACK 0; subscribe ativo para devices do user |
| 4 | Telemetria live atualiza UI | ESP32 publica → 2-3s depois, valor aparece na tela de detalhe |
| 5 | Status online/offline funciona | Desligar ESP32 → badge muda para "Offline" após keepalive timeout |
| 6 | Offline-first | Derrubar rede do celular → app mostra último estado do SQLite imediatamente |
| 7 | Histórico renderiza gráfico | Tela de histórico 24h mostra curva com dados do backend |
| 8 | Claim via QR funciona | Scan QR → claim → device aparece na lista |
| 9 | Rename device funciona | Alterar alias → aparece localmente imediato → sync ao backend via outbox |
| 10 | App background → reconnect | Ir para background 30s+ → voltar → MQTT reconecta automaticamente |
| 11 | JWT refresh transparente | Forçar token expirar → app renova sem interrupção visível |
| 12 | Design system consistente | Todas telas usam componentes Vena (cards, cores, tipografia, espaçamentos) |

---

## Armadilhas conhecidas

| Problema | Solução |
|----------|---------|
| `google_sign_in` no iOS precisa de `GoogleService-Info.plist` | Configurar projeto Firebase/GCP. Usar `serverClientId` correto no Android. |
| Android emulator não alcança `localhost` do host | Usar `10.0.2.2` como alias para o host. |
| iOS simulator não suporta `flutter_secure_storage` no Simulator sem keychain | Funciona, mas sem biometria. Testar em device real para auth biométrica. |
| `mqtt_client` desconecta silenciosamente em background (iOS) | Não manter conexão: desconectar após 30s em background. `AppLifecycleState` listener. |
| Drift code-gen precisa rodar após cada mudança no schema | `dart run build_runner build --delete-conflicting-outputs`. Adicionar ao script de dev. |
| Riverpod code-gen (`@riverpod`) precisa `build_runner` | Mesmo que acima — um único `build_runner build` gera tudo. |
| `fl_chart` tooltip precisa de `GestureDetector` customizado | Usar `touchData` callback do `LineChart`. |
| Ring buffer do `telemetry_cache` pode crescer se prune não rodar | Chamar `pruneOldEntries(deviceId, 1000)` em cada insert batch. |
| MQTT `mqtt_client` Dart logging verboso em debug | Setar `client.logging(on: false)` em prod; `on: true` só em debug builds. |
| Google Sign-In SHA-1 fingerprint | Registrar debug + release SHA-1 no Google Cloud Console. |

---

## Ordem de execução recomendada

```
 1. [Setup]    A1-A2: Criar projeto Flutter + pubspec.yaml com todas deps
 2. [Setup]    A3-A6: Scaffold (main, app, router, theme)
 3. [Design]   B1-B7: Design system tokens + componentes base
 4. [Core]     C1-C9: Drift schema + DAOs (build_runner)
 5. [Core]     D1-D4: Auth (Google Sign-In + secure storage + provider)
 6. [Core]     E1-E3: Dio client + API wrappers
 7. [Core]     F1-F4: MQTT service + provider + message handler + lifecycle
 8. [Core]     G1-G2: Outbox worker + device sync
 9. [Feature]  H1-H2: Splash + Login screen
10. [Feature]  I1-I4: Devices list screen + providers
11. [Feature]  J1-J4: Device detail (live telemetry) + mini-chart
12. [Feature]  K1-K3: History screen + chart
13. [Feature]  L1-L2: Pairing (QR scan + claim)
14. [Tests]    T1-T10: Unit + widget + integration tests
15. [E2E]     Smoke test: login → list → live → history → pair
```

---

## Métricas de sucesso (smoke test final)

1. Instalar app no device/emulator Android.
2. Tap "Entrar com Google" → login bem-sucedido → tela de devices (vazia se primeiro uso).
3. Scan QR code de um device provisionado → claim sucesso → device aparece na lista.
4. Tap no device → tela de detalhe → valor de temperatura atualiza em tempo real (~5s).
5. Desligar ESP32 → badge muda para "Offline" em <30s.
6. Abrir tela de histórico → gráfico 24h renderiza com dados do backend.
7. Renomear device → alias aparece imediato na UI; após resync, persiste no backend.
8. Ativar modo avião → app mostra último estado sem crash; desativar → reconecta e atualiza.

---

## Dependências Flutter (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.4.0
  go_router: ^14.0.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  mqtt_client: ^10.4.0
  dio: ^5.5.0
  google_sign_in: ^6.2.1
  flutter_secure_storage: ^9.2.2
  fl_chart: ^0.69.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  mobile_scanner: ^5.2.3
  phosphor_flutter: ^2.1.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.12
  drift_dev: ^2.18.0
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  mockito: ^5.4.4
  mocktail: ^1.0.4
```

---

## Estrutura final de pastas

```
mobile/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   │       ├── vena_theme.dart
│   │       ├── vena_colors.dart
│   │       └── vena_typography.dart
│   ├── core/
│   │   ├── env.dart
│   │   ├── db/
│   │   │   ├── app_database.dart
│   │   │   ├── tables/
│   │   │   │   ├── devices_table.dart
│   │   │   │   ├── latest_states_table.dart
│   │   │   │   ├── telemetry_cache_table.dart
│   │   │   │   ├── outbox_table.dart
│   │   │   │   └── user_session_table.dart
│   │   │   └── daos/
│   │   │       ├── device_dao.dart
│   │   │       ├── telemetry_dao.dart
│   │   │       └── outbox_dao.dart
│   │   ├── auth/
│   │   │   ├── auth_repository.dart
│   │   │   ├── auth_interceptor.dart
│   │   │   ├── auth_provider.dart
│   │   │   └── secure_token_storage.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   ├── device_api.dart
│   │   │   └── mqtt_api.dart
│   │   ├── mqtt/
│   │   │   ├── mqtt_service.dart
│   │   │   ├── mqtt_provider.dart
│   │   │   ├── mqtt_message_handler.dart
│   │   │   └── mqtt_lifecycle.dart
│   │   └── sync/
│   │       ├── outbox_worker.dart
│   │       └── device_sync_service.dart
│   ├── features/
│   │   ├── auth/
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── splash_screen.dart
│   │   ├── devices/
│   │   │   ├── presentation/
│   │   │   │   ├── devices_screen.dart
│   │   │   │   └── device_card.dart
│   │   │   └── application/
│   │   │       ├── devices_provider.dart
│   │   │       └── device_actions_provider.dart
│   │   ├── live/
│   │   │   ├── presentation/
│   │   │   │   ├── device_detail_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── big_metric.dart
│   │   │   │       └── mini_chart.dart
│   │   │   └── application/
│   │   │       └── live_telemetry_provider.dart
│   │   ├── history/
│   │   │   ├── presentation/
│   │   │   │   ├── history_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── history_chart.dart
│   │   │   └── application/
│   │   │       └── history_provider.dart
│   │   └── pairing/
│   │       ├── presentation/
│   │       │   └── pair_screen.dart
│   │       └── application/
│   │           └── pairing_provider.dart
│   └── design_system/
│       ├── tokens.dart
│       ├── typography.dart
│       └── components/
│           ├── vena_card.dart
│           ├── metric_tile.dart
│           ├── connection_badge.dart
│           ├── vena_button.dart
│           └── empty_state.dart
└── test/
    ├── core/
    │   ├── auth/auth_repository_test.dart
    │   ├── mqtt/mqtt_service_test.dart
    │   └── db/telemetry_dao_test.dart
    └── features/
        ├── devices/devices_screen_test.dart
        └── live/device_detail_screen_test.dart
```
