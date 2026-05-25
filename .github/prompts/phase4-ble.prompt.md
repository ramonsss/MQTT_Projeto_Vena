# Fase 4 — BLE: Comunicação Local e Provisioning

> **Objetivo**: Adicionar BLE GATT ao firmware ESP32 (NimBLE) e ao app Flutter (`flutter_reactive_ble`) para monitoramento local sem internet, provisioning Wi-Fi e pareamento. A tela de detalhe passa a exibir dados de BLE e MQTT simultaneamente, unificados no SQLite, com badge indicando a fonte.
>
> **Pré-requisito**: Fase 3 concluída (app Flutter com login Google, listagem de devices, MQTT live, histórico REST, testes T1–T10 passando, Google Sign-In funcional com `google-services.json`).

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | Lib BLE Flutter | `flutter_reactive_ble` (preferido sobre `flutter_blue_plus` — melhor suporte a bonding, restore, e produção). |
| 2 | Stack BLE firmware | **NimBLE** via `h2zero/NimBLE-Arduino` (menor footprint que Bluedroid, ~50% menos RAM). |
| 3 | Advertising name | `Vena-<últimos 4 hex do MAC>` (ex.: `Vena-D2E3`). Identificação visual rápida. |
| 4 | GATT UUIDs | Namespace custom 128-bit: base `0000XXXX-VENA-4F6C-8E12-A0B765C1D2E3`. Service UUID `0x0001`, characteristics `0x0002`–`0x0006`. |
| 5 | Segurança BLE | **Just Works** pairing (sem PIN) para MVP — simplifica UX. `pairing_code` lido via characteristic requer bonding (encrypted read). |
| 6 | Provisioning | Tela de wizard no app: scan QR → connect BLE → write SSID+PSK+device_jwt → ESP reinicia com Wi-Fi → claim no backend. |
| 7 | Live telemetry BLE | Notify a cada 2s (independente do MQTT 5s) — menor latência local. Payload compacto (binário ou JSON curto). |
| 8 | Coexistência Wi-Fi+BLE | ESP32 suporta ambos simultaneamente. BLE fica sempre ativo (advertising/connected). Wi-Fi pode estar off durante provisioning inicial. |
| 9 | Merge BLE+MQTT no SQLite | Ambas fontes gravam no mesmo `latest_states` e `telemetry_cache` via Drift. Chave `(deviceId, ts)` — mais recente vence. Campo `source` indica origem. |
| 10 | Permissões | Android 12+: `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` (sem Location). Android ≤11: `ACCESS_FINE_LOCATION`. iOS: `NSBluetoothAlwaysUsageDescription`. |
| 11 | Reconexão BLE | Backoff exponencial: 1s → 2s → 4s → ... → 30s (cap). `autoConnect=true` no Android. iOS: `restoreIdentifier` para reconexão em background. |
| 12 | Um device BLE por vez | App mantém **uma única conexão BLE ativa** (limitação prática iOS). Device da tela de detalhe atual. Ao sair da tela, desconecta após 5s. |
| 13 | Formato payload telemetry BLE | JSON curto (mesmo formato MQTT, sem campos opcionais desnecessários) para simplicidade de parse. Avaliar binário apenas se MTU for problema. |
| 14 | MTU negotiation | Solicitar MTU 247 (máximo comum). JSON típico do payload cabe em ~120 bytes — sem fragmentação. |

---

## Contratos

### BLE GATT Service — Vena Service

| Characteristic | UUID suffix | Propriedades | Descrição |
|---|---|---|---|
| `device_info` | `0x0002` | Read | JSON: `{"device_id":"vena-a0b765c1d2e3","fw_version":"1.2.0","capabilities":["telemetry","peltier"]}` |
| `live_telemetry` | `0x0003` | Notify | JSON a cada 2s: `{"ts":1737830400000,"at":22.5,"ah":65.2,"dt":18.3,"dh":60.1,"sp":18.0,"po":120}` |
| `wifi_status` | `0x0004` | Read, Notify | JSON: `{"connected":true,"ssid":"FazendaWifi","ip":"192.168.1.42","rssi":-65}` ou `{"connected":false}` |
| `wifi_provisioning` | `0x0005` | Write | Input JSON: `{"ssid":"...","psk":"...","jwt":"<device_jwt>"}`. ESP salva em NVS, reinicia Wi-Fi. |
| `pairing_code` | `0x0006` | Read (encrypted) | Retorna `"K7X9-M2P4"` — requer bonding ativo. |

### Backend REST (novos ou alterados)

| Endpoint | Método | Uso |
|---|---|---|
| `POST /devices/provision` | POST | Body: `{"device_id":"vena-...", "pairing_code":"K7X9-M2P4"}`. Retorna `{"device_jwt":"<jwt>"}` para o ESP. Chamado pelo app durante wizard. |
| `POST /devices/{id}/claim` | POST | Já existe (Fase 2). App chama após provisioning bem-sucedido. |

---

## Checklist de implementação

### A. Firmware — NimBLE GATT

| # | Arquivo/Pasta | O que faz |
|---|---|---|
| A1 | `firmware/platformio.ini` | Adicionar `h2zero/NimBLE-Arduino@^2.1.0` em `lib_deps`. Adicionar build flag `-D CONFIG_BT_NIMBLE_ROLE_BROADCASTER -D CONFIG_BT_NIMBLE_ROLE_PERIPHERAL`. |
| A2 | `firmware/include/config.h` | Adicionar bloco BLE: `BLE_DEVICE_PREFIX "Vena-"`, UUIDs do service e characteristics, `BLE_NOTIFY_INTERVAL_MS 2000`, `BLE_MTU 247`. |
| A3 | `firmware/lib/BleManager/BleManager.h` | Declaração da classe: `init()`, `startAdvertising()`, `stopAdvertising()`, `isConnected()`, `notifyTelemetry(payload)`, `setWifiProvisioningCallback(cb)`. |
| A4 | `firmware/lib/BleManager/BleManager.cpp` | Implementação NimBLE: cria server, service, characteristics. Callbacks para connect/disconnect, write em `wifi_provisioning`, read em `device_info`/`pairing_code`. Notify loop em `live_telemetry`. |
| A5 | `firmware/include/ble_uuids.h` | Constantes UUID 128-bit para service e cada characteristic. Separado para clareza. |
| A6 | `firmware/src/main.cpp` | Integrar `BleManager::init()` no `setup()`. No `loop()`, chamar `bleManager.notifyTelemetry()` a cada 2s (timer separado do MQTT 5s). Callback de provisioning → salvar NVS + restart Wi-Fi. |
| A7 | `firmware/lib/BleManager/BleCallbacks.h` | Classes callback NimBLE: `ServerCallbacks` (connect/disconnect log), `ProvisioningCallbacks` (onWrite → parse JSON → validar → salvar NVS). |

### B. Firmware — Provisioning Wi-Fi via BLE

| # | Arquivo | O que faz |
|---|---|---|
| B1 | `firmware/lib/WifiProvisioner/WifiProvisioner.h` | Classe que encapsula: `saveCredentials(ssid, psk, jwt)` → NVS, `loadCredentials()` → struct, `clearCredentials()`, `hasCredentials() → bool`. |
| B2 | `firmware/lib/WifiProvisioner/WifiProvisioner.cpp` | Implementação com `Preferences.h` (NVS). Armazena SSID, PSK, device JWT. Chamado pelo callback BLE e no boot para auto-connect. |
| B3 | `firmware/src/main.cpp` (alteração) | No `setup()`: se `WifiProvisioner::hasCredentials()` → tenta Wi-Fi com credenciais salvas; senão → fica em modo "BLE-only" (advertising, sem MQTT). |

### C. Flutter — Package & Permissões

| # | Arquivo | O que faz |
|---|---|---|
| C1 | `mobile/pubspec.yaml` | Adicionar: `flutter_reactive_ble: ^5.3.1`, `permission_handler: ^11.3.1`. |
| C2 | `mobile/android/app/src/main/AndroidManifest.xml` | Adicionar permissions: `BLUETOOTH_SCAN` (com `usesPermissionFlags="neverForLocation"`), `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` (para Android ≤11). Feature: `android.hardware.bluetooth_le`. |
| C3 | `mobile/ios/Runner/Info.plist` | Adicionar: `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`. Em `UIBackgroundModes` → `bluetooth-central`. |

### D. Flutter — Core BLE Service

| # | Arquivo | O que faz |
|---|---|---|
| D1 | `mobile/lib/core/ble/ble_service.dart` | Classe `BleService`: `scanForVenaDevices() → Stream<DiscoveredDevice>`, `connect(deviceId) → Stream<ConnectionState>`, `disconnect()`, `readDeviceInfo() → DeviceInfo`, `subscribeTelemetry() → Stream<BleTelemetry>`, `readWifiStatus() → WifiStatus`, `writeWifiProvisioning(ssid, psk, jwt)`, `readPairingCode() → String`. Internamente usa `FlutterReactiveBle`. |
| D2 | `mobile/lib/core/ble/ble_uuids.dart` | Constantes Dart dos UUIDs GATT (mirror do firmware). `Uuid` objects para service e cada characteristic. |
| D3 | `mobile/lib/core/ble/ble_models.dart` | Freezed models: `DiscoveredVenaDevice(id, name, rssi)`, `BleTelemetry(ts, ambientT, ambientH, dissT, dissH, setpoint, pidOut)`, `BleDeviceInfo(deviceId, fwVersion, capabilities)`, `BleWifiStatus(connected, ssid, ip, rssi)`. |
| D4 | `mobile/lib/core/ble/ble_provider.dart` | Riverpod providers: `bleServiceProvider` (singleton), `bleScanProvider` → `StreamProvider<List<DiscoveredVenaDevice>>`, `bleConnectionProvider(deviceMac)` → `StateNotifierProvider` com estados `idle/scanning/connecting/connected/streaming/error`. |
| D5 | `mobile/lib/core/ble/ble_message_handler.dart` | Recebe `BleTelemetry` do stream → upsert `latest_states` (source='ble') + insert `telemetry_cache`. Mesmo padrão do `mqtt_message_handler`. |
| D6 | `mobile/lib/core/ble/ble_permission_handler.dart` | Helper: `requestBlePermissions() → PermissionStatus`. Lógica condicional Android 12+ vs ≤11. Mostra dialog explicativo se negado. |

### E. Flutter — Feature Pairing (refactor do wizard existente)

| # | Arquivo | O que faz |
|---|---|---|
| E1 | `mobile/lib/features/pairing/presentation/pair_screen.dart` (refactor) | Wizard 4 passos agora: (1) Scan QR → extrai `device_id` + `pairing_code`, (2) Busca device via BLE scan → conecta, (3) Se device sem Wi-Fi: provisioning (input SSID+PSK + busca device_jwt no backend) → write BLE → aguarda confirmação, (4) Claim no backend → sucesso. |
| E2 | `mobile/lib/features/pairing/presentation/widgets/ble_scan_step.dart` | Widget: mostra lista de Venas BLE próximas (com RSSI como indicador de proximidade). User toca na correta. Timeout 15s com retry. |
| E3 | `mobile/lib/features/pairing/presentation/widgets/wifi_provision_step.dart` | Widget: form SSID + PSK, botão "Configurar Wi-Fi". Mostra progress enquanto ESP conecta. Lê `wifi_status` para confirmar sucesso. |
| E4 | `mobile/lib/features/pairing/presentation/widgets/pairing_success_step.dart` | Widget: confirmação visual com animação, input de alias, botão "Concluir". |
| E5 | `mobile/lib/features/pairing/application/pairing_provider.dart` (refactor) | Agora gerencia: `scanQr → scanBle → connectBle → provision (se necessário) → claim → done`. State machine com estados para cada passo. |
| E6 | `mobile/lib/features/pairing/application/provisioning_service.dart` | `provisionDevice(deviceId, pairingCode, ssid, psk)`: chama `POST /devices/provision` → recebe `device_jwt` → escreve via BLE → poll `wifi_status` até connected (timeout 30s). |

### F. Flutter — Device Detail (BLE + MQTT merge)

| # | Arquivo | O que faz |
|---|---|---|
| F1 | `mobile/lib/features/live/application/ble_live_provider.dart` | `bleTelemetryProvider(deviceId)`: conecta BLE ao entrar na tela → subscribe telemetry notify → emite stream de `BleTelemetry`. Desconecta ao sair (com delay 5s para evitar reconexão desnecessária ao navegar rápido). |
| F2 | `mobile/lib/features/live/application/live_telemetry_provider.dart` (alteração) | Agora combina: `latestStateProvider(deviceId)` lê do Drift (que recebe de BLE + MQTT). Adicionar `sourceProvider(deviceId)` computed que indica fonte do dado mais recente. |
| F3 | `mobile/lib/features/live/presentation/device_detail_screen.dart` (alteração) | Adicionar `ConnectionBadge` mostrando fonte: "BLE" (ícone Bluetooth, verde), "MQTT" (ícone Wi-Fi, azul), "Offline" (ícone cloud-off, cinza). Mostra qual fonte está ativa baseado no `sourceProvider`. |
| F4 | `mobile/lib/features/live/presentation/widgets/connection_badge.dart` (alteração) | Expandir para 3 estados: `ble`, `mqtt`, `offline`. Cada um com ícone, cor e micro-animação pulse quando ativo. |
| F5 | `mobile/lib/core/ble/ble_lifecycle.dart` | Mixin/listener `AppLifecycleState`: em `resumed` → reconecta BLE se tela de detalhe ativa; em `paused` → desconecta BLE após 5s. |

### G. Backend — Provisioning endpoint

| # | Arquivo | O que faz |
|---|---|---|
| G1 | `backend/app/devices/routes.py` (alteração) | Novo endpoint `POST /devices/provision`: recebe `{device_id, pairing_code}`, valida pairing_code contra hash do device → gera device JWT (scope=device, longa duração) → retorna `{device_jwt}`. |
| G2 | `backend/app/auth/jwt.py` (alteração) | Nova função `create_device_jwt(device_id) → str`: JWT com `sub=device:{id}`, `scope=device`, `exp=1 ano`. |
| G3 | `backend/app/devices/schemas.py` (alteração) | Novo schema `ProvisionRequest(device_id: str, pairing_code: str)` e `ProvisionResponse(device_jwt: str)`. |

---

## Firmware — Estrutura do BleManager

```cpp
// BleManager.h (simplificado)
#pragma once
#include <NimBLEDevice.h>
#include <functional>

struct WifiCredentials {
    String ssid;
    String psk;
    String jwt;
};

using ProvisionCallback = std::function<void(const WifiCredentials&)>;

class BleManager {
public:
    void init(const char* deviceName, const char* deviceId, const char* pairingCode);
    void startAdvertising();
    void stopAdvertising();
    bool isConnected();
    void notifyTelemetry(const char* jsonPayload);
    void updateWifiStatus(bool connected, const char* ssid, const char* ip, int rssi);
    void setProvisionCallback(ProvisionCallback cb);

private:
    NimBLEServer* _server = nullptr;
    NimBLECharacteristic* _telemetryChar = nullptr;
    NimBLECharacteristic* _wifiStatusChar = nullptr;
    NimBLECharacteristic* _provisionChar = nullptr;
    NimBLECharacteristic* _deviceInfoChar = nullptr;
    NimBLECharacteristic* _pairingCodeChar = nullptr;
    ProvisionCallback _provisionCb = nullptr;
    bool _connected = false;
};
```

---

## Flutter — State Machine BLE

```
┌───────────────────────────────────────────────────────────────────┐
│                    BLE Connection State Machine                     │
│                                                                   │
│  ┌──────┐   scan()   ┌──────────┐  found   ┌────────────┐       │
│  │ idle │ ──────────▶ │ scanning │ ────────▶ │ discovered │       │
│  └──────┘             └──────────┘           └─────┬──────┘       │
│      ▲                     │ timeout                │ connect()    │
│      │                     ▼                        ▼              │
│      │              ┌───────────┐            ┌────────────┐       │
│      │              │  timeout  │            │ connecting │       │
│      │              │  (retry?) │            └─────┬──────┘       │
│      │              └───────────┘                  │ success      │
│      │                                             ▼              │
│      │                                      ┌────────────┐       │
│      │ disconnect()                         │  connected  │       │
│      │◀─────────────────────────────────────│ (bonded)    │       │
│      │                                      └─────┬──────┘       │
│      │                                             │ subscribe    │
│      │              ┌───────────┐                  ▼              │
│      │◀─── error ──│   error    │◀─────── ┌────────────┐        │
│      │              │ (backoff) │          │ streaming  │        │
│      │              └───────────┘          │ (notify)   │        │
│      │                                     └────────────┘        │
│      │                                             │              │
│      │◀────── disconnect / leave screen ───────────┘              │
└───────────────────────────────────────────────────────────────────┘
```

---

## Fluxo de Provisioning — Diagrama

```
┌───────┐        ┌───────────┐        ┌────────┐        ┌─────────┐
│  App  │        │ ESP32 BLE │        │Backend │        │ Broker  │
└───┬───┘        └─────┬─────┘        └───┬────┘        └────┬────┘
    │                   │                  │                   │
    │ 1. Scan QR        │                  │                   │
    │ (device_id +      │                  │                   │
    │  pairing_code)    │                  │                   │
    │                   │                  │                   │
    │ 2. BLE scan       │                  │                   │
    │──────────────────▶│ (advertising)    │                   │
    │ 3. Connect        │                  │                   │
    │──────────────────▶│                  │                   │
    │ 4. Bond (Just Works)                 │                   │
    │◀─────────────────▶│                  │                   │
    │                   │                  │                   │
    │ 5. Read device_info                  │                   │
    │──────────────────▶│                  │                   │
    │◀──────────────────│ {device_id, fw}  │                   │
    │                   │                  │                   │
    │ 6. POST /devices/provision           │                   │
    │  {device_id, pairing_code}           │                   │
    │─────────────────────────────────────▶│                   │
    │◀─────────────────────────────────────│                   │
    │ 7. Recebe device_jwt                 │                   │
    │                   │                  │                   │
    │ 8. Write wifi_provisioning           │                   │
    │  {ssid, psk, jwt} │                  │                   │
    │──────────────────▶│                  │                   │
    │                   │ 9. Salva NVS     │                   │
    │                   │ 10. Connect WiFi │                   │
    │                   │─────────────────────────────────────▶│
    │                   │ 11. MQTT connect(device_jwt)          │
    │                   │─────────────────────────────────────▶│
    │                   │                  │                   │
    │ 12. Read wifi_status (poll)          │                   │
    │──────────────────▶│                  │                   │
    │◀──────────────────│ {connected:true} │                   │
    │                   │                  │                   │
    │ 13. POST /devices/{id}/claim         │                   │
    │─────────────────────────────────────▶│                   │
    │◀─────────────────────────────────────│ 200 OK            │
    │                   │                  │                   │
    │ 14. Disconnect BLE │                 │                   │
    │──────────────────▶│                  │                   │
    │                   │                  │                   │
    │ 15. Navigate → /devices              │                   │
```

---

## Merge BLE + MQTT — Diagrama

```
┌────────────────────────────────────────────────────────────┐
│  Device Detail Screen                                       │
│                                                            │
│  ┌──────────────┐     ┌──────────────────┐                │
│  │ BLE Service  │     │  MQTT Service    │                │
│  │ (2s notify)  │     │  (5s publish)    │                │
│  └──────┬───────┘     └────────┬─────────┘                │
│         │                      │                           │
│         ▼                      ▼                           │
│  ┌─────────────┐       ┌─────────────┐                    │
│  │ BLE Handler │       │ MQTT Handler│                    │
│  │ source='ble'│       │ source='mqtt'│                   │
│  └──────┬──────┘       └──────┬──────┘                    │
│         │                      │                           │
│         └──────────┬───────────┘                           │
│                    ▼                                        │
│         ┌──────────────────┐                               │
│         │  Drift SQLite    │                               │
│         │  latest_states   │  UPSERT WHERE new.ts > old.ts │
│         │  telemetry_cache │                               │
│         └────────┬─────────┘                               │
│                  │ Stream                                   │
│                  ▼                                          │
│         ┌──────────────────┐                               │
│         │ latestState      │                               │
│         │ Provider         │                               │
│         │ (Riverpod)       │                               │
│         └────────┬─────────┘                               │
│                  ▼                                          │
│         ┌──────────────────┐                               │
│         │       UI         │                               │
│         │ Temp + Badge     │                               │
│         │ [BLE] ou [MQTT]  │                               │
│         └──────────────────┘                               │
└────────────────────────────────────────────────────────────┘
```

---

## Testes

| # | O que valida |
|---|---|
| T1 | `BleService.scanForVenaDevices()` — mock `FlutterReactiveBle`, retorna lista filtrada por nome `Vena-*`. |
| T2 | `BleService.connect()` + `subscribeTelemetry()` — mock connection stream → emite `connected` → subscribe retorna dados de notify. |
| T3 | `BleMessageHandler` — `BleTelemetry` → upsert `latest_states` com `source='ble'` + insert `telemetry_cache`. Verifica que `ts` mais recente vence. |
| T4 | `BlePermissionHandler` — mock `permission_handler`: cenário granted → retorna ok; cenário denied → retorna denied com mensagem. |
| T5 | `ProvisioningService.provisionDevice()` — mock backend `/devices/provision` + mock BLE write + mock wifi_status read → confirma fluxo completo. |
| T6 | `PairingProvider` state machine — simula fluxo QR → BLE scan → connect → provision → claim → done. Verifica cada transição de estado. |
| T7 | `bleTelemetryProvider` — emite dados BLE enquanto conectado; para ao desconectar; reconecta com backoff após erro. |
| T8 | Widget test: `DeviceDetailScreen` com BLE ativo — badge mostra "BLE", valor atualiza ao receber notify do stream mockado. |
| T9 | Widget test: `BleScanStep` — mostra lista de devices descobertos, tap seleciona, timeout mostra retry. |
| T10 | Widget test: `WifiProvisionStep` — form validate (SSID obrigatório, PSK min 8 chars), submit → progress → success/error. |
| T11 | Integration: merge BLE+MQTT — simula BLE com ts=100 e MQTT com ts=102 → latest_states mostra ts=102 source='mqtt'. Depois BLE ts=104 → atualiza para source='ble'. |
| T12 | Firmware unit test (PlatformIO): `BleManager` inicializa service com UUIDs corretos; `notifyTelemetry` serializa payload; provisioning callback dispara com credenciais parseadas. |

---

## Critérios de aceite (DoD)

| # | Critério | Como verificar |
|---|----------|----------------|
| 1 | ESP32 faz advertising BLE com nome `Vena-XXXX` | Scanner genérico (nRF Connect) vê o device |
| 2 | App descobre Venas próximas via BLE scan | Tela de scan mostra device com RSSI |
| 3 | Conexão BLE + bonding funciona | App conecta, bond persiste entre reinícios |
| 4 | `device_info` retorna JSON válido | nRF Connect ou app lê characteristic com sucesso |
| 5 | Telemetry notify funciona a cada 2s | Tela de detalhe atualiza com dados BLE; badge mostra "BLE" |
| 6 | Provisioning Wi-Fi via BLE funciona | ESP sem Wi-Fi → app envia credenciais → ESP conecta → status muda para online |
| 7 | ESP mantém BLE + Wi-Fi simultaneamente | Após provisioning, BLE continua disponível enquanto MQTT publica |
| 8 | Merge BLE + MQTT no SQLite | Ambas fontes gravam; UI mostra dado mais recente; badge alterna corretamente |
| 9 | Wizard de pairing completo funciona | QR → BLE scan → connect → provision → claim → device na lista |
| 10 | Permissões tratadas graciosamente | Sem permissão → dialog explicativo → deep link para settings |
| 11 | Reconexão BLE com backoff | Desconectar ESP → app retenta; reconectar ESP → streaming retoma em <10s |
| 12 | Desconexão ao sair da tela | Navegar para outra tela → BLE desconecta após 5s; voltar → reconecta |
| 13 | RAM do ESP32 suficiente | `ESP.getFreeHeap()` > 50KB com BLE + Wi-Fi + MQTT + sensores ativos |
| 14 | iOS background restore | App em background → iOS mantém referência → ao retornar, reconecta automaticamente |

---

## Armadilhas conhecidas

| Problema | Solução |
|----------|---------|
| NimBLE + Wi-Fi usa muita RAM no ESP32 | Desativar Bluedroid (NimBLE é lighter). Monitor `ESP.getFreeHeap()`. Reduzir stack sizes se necessário. |
| BLE advertising para quando conectado (1 client) | Design: apenas 1 app conectado por vez. Se precisar mais, usar `NimBLEDevice::setMaxConnections(2)` — mas não recomendado para MVP. |
| `flutter_reactive_ble` não descobre device se permissions negadas silenciosamente | Sempre verificar permissões ANTES de iniciar scan. Mostrar rationale no primeiro request. |
| Android 12 crash se declarar `ACCESS_FINE_LOCATION` sem `usesPermissionFlags` | Usar `android:usesPermissionFlags="neverForLocation"` em `BLUETOOTH_SCAN` para Android 12+. |
| iOS mata BLE em background após ~30s sem activity | Usar `restoreIdentifier` no scan/connect. Não depender de BLE background para dados — MQTT cobre isso. |
| ESP32 NVS corrompido perde credenciais | Verificar `nvs_flash_init()` return; se `ESP_ERR_NVS_NO_FREE_PAGES` → erase e re-init. Provisioning pode ser refeito. |
| MTU default 23 bytes trunca JSON | Negociar MTU 247 no connect. Se MTU negotiation falhar, truncar payload para campos essenciais. |
| Bonding não persiste em factory reset do celular | Esperado. User refaz bonding automaticamente ao conectar. Não afeta funcionalidade. |
| Wi-Fi desconecta durante BLE provisioning no ESP | ESP está em modo BLE-only durante provisioning; Wi-Fi inicia APÓS write da characteristic. Sem conflito. |
| Dois handlers (BLE+MQTT) gravando no SQLite simultaneamente | Drift handles concurrent writes (SQLite WAL mode). PK `(deviceId, ts)` evita duplicatas. Sem race condition. |
| `flutter_reactive_ble` deprecated? | À data do plano é mantido. Alternativa: `flutter_blue_plus`. Avaliar se houver breaking issues. |
| BLE characteristic read retorna bytes, não String | Decode com `utf8.decode(value)` no Dart. No firmware, write com `setValue(std::string)`. |

---

## Ordem de execução recomendada

```
 1. [Firmware]    A1-A2: Adicionar NimBLE ao platformio.ini + config.h (UUIDs, defines)
 2. [Firmware]    A3-A5: Criar BleManager (init, advertising, GATT service, characteristics)
 3. [Firmware]    A6-A7: Integrar BleManager no main.cpp + callbacks
 4. [Firmware]    B1-B3: WifiProvisioner (NVS save/load) + lógica condicional no boot
 5. [Validate]    Testar com nRF Connect: advertising visível, read device_info, notify telemetry
 6. [Flutter]     C1-C3: Adicionar packages + permissões Android/iOS
 7. [Flutter]     D1-D3: BleService + UUIDs + models
 8. [Flutter]     D4-D6: Providers BLE + message handler + permission handler
 9. [Flutter]     F1-F2: BLE live provider + merge no latestStateProvider
10. [Flutter]     F3-F5: UI badge BLE/MQTT + lifecycle
11. [Flutter]     E1-E6: Wizard pairing refactor (QR → BLE scan → provision → claim)
12. [Backend]     G1-G3: Endpoint POST /devices/provision + device JWT
13. [Tests]       T1-T7: Unit tests core BLE
14. [Tests]       T8-T11: Widget tests + integration test merge
15. [Tests]       T12: Firmware unit test BleManager
16. [E2E]         Smoke test: provisioning completo + live BLE + merge com MQTT
```

---

## Métricas de sucesso (smoke test final)

1. **Advertising**: ESP32 liga, aparece como `Vena-XXXX` no nRF Connect e no app.
2. **Provisioning completo**: ESP32 sem Wi-Fi → app faz scan QR → conecta BLE → provisiona → ESP32 fica online (MQTT ativo).
3. **BLE live**: tela de detalhe mostra temperatura atualizando a cada ~2s com badge "BLE" enquanto perto do device.
4. **MQTT fallback**: afastar-se do device (BLE desconecta) → badge muda para "MQTT" → dados continuam chegando via broker.
5. **Merge correto**: aproximar novamente → badge volta para "BLE"; dado mais recente (por `ts`) sempre prevalece.
6. **Pairing novo device**: QR de device virgem → provisioning Wi-Fi → claim → aparece na lista.
7. **Reconexão**: desligar/religar ESP32 → app reconecta BLE em <30s sem intervenção.
8. **RAM estável**: `ESP.getFreeHeap()` reportado em serial > 50KB após 10min de operação (BLE + Wi-Fi + MQTT).
9. **Permissões**: negar Bluetooth → app mostra dialog explicativo com botão para Settings; conceder → scan funciona.

---

## Dependências novas

### Flutter (`pubspec.yaml`)

```yaml
dependencies:
  flutter_reactive_ble: ^5.3.1
  permission_handler: ^11.3.1
```

### Firmware (`platformio.ini`)

```ini
lib_deps =
    ...existing...
    h2zero/NimBLE-Arduino@^2.1.0
```

### Backend (sem novas deps — apenas novos endpoints)

---

## Escopo explicitamente FORA desta fase

- **OTA via BLE** — complexidade alta, pouco valor no MVP. Firmware update manual por USB.
- **Múltiplas conexões BLE simultâneas** — uma por vez é suficiente para UX de produtor.
- **BLE Mesh** — desnecessário; cada Vena opera independentemente.
- **Notificações push baseadas em BLE proximity** — fase posterior (FCM + geofencing).
- **Criptografia customizada no payload BLE** — bonding/encryption nativo do BLE 4.2+ é suficiente.
- **BLE em background contínuo no app** — bateria proibitiva. MQTT cobre dados remotos; BLE é para interação ativa.
