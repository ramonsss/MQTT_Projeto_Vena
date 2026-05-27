# Fase 5 — Preparação para Demo de Feira

> **Objetivo**: Fechar o produto para a apresentação na feira (~15 dias). Inclui três pequenas melhorias de UX/UI (campo de conteúdo armazenado no pareamento, edição via long-press na listagem, correção do bug de dark mode), ampliação do BLE para conexões simultâneas (até 3 visitantes ao vivo) e a estratégia de deploy híbrida (Supabase para Postgres + VPS gratuita para broker MQTT/FastAPI). Esta fase **precede** a Fase 5 do plano arquitetural ("Agregação e produção") e foca em estabilidade e impacto visual para o demo.
>
> **Pré-requisito**: Fases 1–4 concluídas (telemetria E2E, auth, app mobile, BLE provisioning + live). Suite de testes T1–T11 verde e smoke test de integração funcionando.

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | **Campo "conteúdo armazenado"** | Opcional com botão "Pular". Três botões de seleção rápida (`Cacau`, `Pimenta-do-reino`, `Outro`); ao escolher *Outro*, abre `TextField` (max 40 chars). |
| 2 | **Persistência do conteúdo** | **Apenas no app** (Drift/SQLite). Sem alteração de schema no backend nesta fase — minimiza retrabalho e atende o demo. Migração para backend fica como dívida documentada. |
| 3 | **Trigger de edição** | **Long-press** no `DeviceCard` da listagem → abre `ModalBottomSheet` com campos `alias` e `storedContent`. Sem ícone visível (mantém card limpo). Tooltip discreto no primeiro uso (opcional). |
| 4 | **Dark mode** | **Forçar tema claro sempre**. `MaterialApp.themeMode = ThemeMode.light` em `app.dart` e remover (ou manter dormente) o método `VenaTheme.dark()`. Identidade visual única, resolve o bug de leitura nos cards e elimina QA dual-theme. |
| 5 | **BLE multi-conexão** | NimBLE configurado para **3 conexões simultâneas** (`CONFIG_BT_NIMBLE_MAX_CONNECTIONS=3`). Após `onConnect`, reinicia advertising para que outros visitantes vejam o device. Token JWT continua exigido para gravar Wi-Fi (provisioning), mas leitura de telemetria fica aberta no demo. |
| 6 | **Deploy — Postgres** | **Supabase free tier** (500 MB, 50K MAU, 200 conexões simultâneas — folgado para o demo). SQLAlchemy aponta direto para `postgres://...supabase.co:5432/postgres` com SSL. TimescaleDB **não** disponível no free tier — fallback para Postgres puro com índice em `(device_id, ts DESC)`. |
| 7 | **Deploy — Broker + Backend** | VPS gratuita única rodando `docker compose` com `mosquitto`, `fastapi`, `mqtt-worker`, `redis`. **Recomendação forte**: **Oracle Cloud Always Free** (4 vCPU ARM + 24 GB RAM, sem time-out, sem dormir). Alternativa Fly.io free é arriscada (256 MB total). |
| 8 | **Hostname / TLS** | Domínio em DuckDNS (gratuito) + Caddy como reverse proxy com Let's Encrypt automático. Mosquitto exposto em `:8883` (MQTT/TLS) ou `:8083` (WSS). Backend FastAPI em `:443` (HTTPS via Caddy). |
| 9 | **APK de distribuição** | Build `release` único universal (arm64-v8a + armeabi-v7a), tamanho-alvo < 40 MB. Distribuído via QR code para download direto (arquivo hospedado em GitHub Releases ou no próprio VPS via Caddy). |
| 10 | **Plano B se VPS cair** | Manter `main_mock.dart` funcional e build alternativa `vena-mock.apk` no QR de fallback. Stand recebe ambos APKs em pen-drive físico. |

---

## Reflexões respondidas (opinião direta)

### A. "A preocupação com o plano gratuito faz sentido?"
**Sim, parcialmente.** O risco real **não é o banco** (50 usuários × ~2 KB/req de histórico = ~100 KB → trivial para Supabase free). O risco é o **broker MQTT** e a **VPS gratuita típica**:
- Render free / Railway free **dormem após 15 min** de inatividade → fatal para Mosquitto, que precisa de conexão persistente.
- Fly.io free dá 3 VMs de 256 MB → insuficiente para Mosquitto + FastAPI + worker juntos.
- **Oracle Always Free (ARM 24 GB)** ou Hetzner CX22 (€4/mês = ~R$ 24 pelo demo inteiro) eliminam o problema.

### B. "Faria sentido subir o banco em Supabase em vez de na VPS?"
**Sim, faz total sentido.** Vantagens concretas para o demo:
- Backups automáticos diários (perder dados durante a apresentação = pesadelo).
- Painel SQL web — você abre o navegador e mostra a tabela `telemetry` enchendo ao vivo (efeito wow para banca).
- Connection pooling embutido (PgBouncer transacional) → SQLAlchemy não derruba o DB com conexões mortas.
- Zero setup de manutenção; foco fica no broker e backend.
- **Retrabalho mínimo**: alterar apenas `DATABASE_URL` no `.env` e adicionar `sslmode=require`. Sem mudança de código.

**Único risco**: TimescaleDB não está no free tier. Mas para o demo (1 device físico, ~17K linhas/dia, queries de janela curta), Postgres puro com índice composto resolve. Adicionar hypertable fica para Fase 6.

### C. "Mais de uma pessoa consegue receber dados do ESP por BLE?"
**Sim — o ESP32 suporta tecnicamente, mas exige configuração explícita.** Por padrão o NimBLE-Arduino aceita só 1 conexão. Aumentando `CONFIG_BT_NIMBLE_MAX_CONNECTIONS` (até 9) e re-emitindo `startAdvertising()` no callback `onConnect`, vários celulares conectam ao mesmo tempo.

**Recomendação para a feira**: **3 conexões simultâneas**. Justificativa:
- Permite cena com 3 visitantes vendo dados ao vivo em paralelo (impacto visual).
- Acima de 3 a largura de banda BLE 4.2 começa a degradar (notify a cada 2s × 3 clientes = OK; × 9 = jitter perceptível).
- 1 conexão funciona mas cria fila e quebra o ritmo da apresentação.
- iOS limita conexões por app; com 3 já se vê o efeito sem entrar em armadilhas de plataforma.

---

## Contratos

### Schema Drift — nova coluna em `devices`

```dart
TextColumn get storedContent => text().nullable()();
```

Migration `from v2 to v3`:
```dart
await m.addColumn(devices, devices.storedContent);
```

Sem backend correspondente nesta fase. Outbox **não** sincroniza este campo.

### Outbox — ação `rename` estendida ou nova `update_alias`

Manter a ação `rename` (alias já sincroniza). Edição de `storedContent` **fica só local** — não vai ao outbox.

### BLE — firmware

`include/config.h`:
```cpp
#define CONFIG_BT_NIMBLE_MAX_CONNECTIONS 3
```

`MqttPublisher.cpp` (ou onde o BLE server vive): após `onConnect`, chamar `NimBLEDevice::startAdvertising()` para manter o device descobrível.

### Theme — `app.dart`

```dart
return MaterialApp.router(
  theme: VenaTheme.light(),
  themeMode: ThemeMode.light, // ← força tema claro
  // darkTheme: VenaTheme.dark(), // remover ou deixar comentado
  ...
);
```

### Deploy — `docker-compose.yml` mínimo na VPS

```yaml
services:
  caddy:        # 443 + 80 + ACME
  mosquitto:    # 1883 + 8883 + 8083
  fastapi:      # interno 8000
  mqtt-worker:  # consome MQTT → Supabase
  redis:        # cache + rate-limit (opcional)
```

`.env` de produção aponta `DATABASE_URL=postgresql+asyncpg://...@db.PROJECT.supabase.co:5432/postgres?ssl=require`.

---

## Checklist de implementação

### A. Bug fix — Dark mode (rápido, ~30 min)
- [ ] Em `mobile/lib/app.dart` adicionar `themeMode: ThemeMode.light`.
- [ ] Remover (ou marcar `@Deprecated`) `VenaTheme.dark()` em `app_theme.dart`.
- [ ] Smoke manual: simular dark mode no emulador (Settings → Display → Dark theme) e confirmar que o app permanece claro.

### B. Campo "conteúdo armazenado" no pareamento
- [ ] **Drift**: bumpear `schemaVersion` para 3, adicionar coluna `storedContent` em `Devices`, escrever migration.
- [ ] Regenerar build_runner (`dart run build_runner build --delete-conflicting-outputs`).
- [ ] **UI**: criar widget `StoredContentSelector` em `mobile/lib/features/pairing/presentation/widgets/`:
  - Três `ChoiceChip`s coloridos: `Cacau` (marrom #6B4226), `Pimenta-do-reino` (preto #2C2C2C), `Outro` (cinza).
  - Estado `Outro` revela `TextField` com `maxLength: 40`.
  - Botão "Pular" abaixo dos chips.
- [ ] Integrar em `PairingSuccessStep` (ou step de alias atual) — gravação no Drift quando `alias` é confirmado.
- [ ] Exibir o conteúdo abaixo do alias no `DeviceCard` (badge discreto com ícone).

### C. Edição via long-press na listagem
- [ ] Em `device_card.dart`, envolver o `Card` em `GestureDetector(onLongPress: () => _showEditSheet(context, device))`.
- [ ] Criar `EditDeviceBottomSheet` com dois campos:
  - `TextField` para alias (com validação não-vazio).
  - `StoredContentSelector` (reusar widget da Tarefa B) com valor atual pré-selecionado.
  - Botão "Salvar" (chama `deviceActionsProvider`).
- [ ] Estender `DeviceActions` com `updateStoredContent(deviceId, content)` — atualização local-apenas via `db.deviceDao.updateStoredContent(...)`.
- [ ] Reaproveitar `renameDevice` existente para o alias.
- [ ] Haptic feedback no long-press (`HapticFeedback.mediumImpact()`).

### D. BLE multi-conexão no firmware
- [ ] Em `firmware/include/config.h`, adicionar `#define CONFIG_BT_NIMBLE_MAX_CONNECTIONS 3`.
- [ ] Em `platformio.ini`, garantir `build_flags = -DCONFIG_BT_NIMBLE_MAX_CONNECTIONS=3`.
- [ ] No callback `onConnect` do `NimBLEServerCallbacks`, chamar `NimBLEDevice::startAdvertising()`.
- [ ] Testar com 2 celulares Android + 1 iPhone conectados simultaneamente — confirmar notify a cada 2s em todos.
- [ ] Documentar no README do firmware: "MVP suporta até 3 visitantes BLE simultâneos".

### E. Deploy — Supabase (DB)
- [ ] Criar projeto em supabase.com (região South America – São Paulo).
- [ ] Executar migrations Alembic apontando para Supabase (`alembic upgrade head`).
- [ ] Criar índice manual: `CREATE INDEX idx_telemetry_device_ts ON telemetry (device_id, ts DESC);`.
- [ ] Configurar Row Level Security desabilitado para tabelas internas (auth fica no FastAPI, não no Supabase Auth).
- [ ] Anotar `DATABASE_URL` e service role key em `.env.prod`.

### F. Deploy — VPS (broker + backend)
- [ ] Provisionar Oracle Always Free VM (Ubuntu 22.04 ARM 24 GB).
- [ ] Instalar Docker + Docker Compose.
- [ ] Configurar DuckDNS subdomínio (`vena-demo.duckdns.org`).
- [ ] Subir `docker-compose.prod.yml` com Caddy, Mosquitto, FastAPI, MQTT worker.
- [ ] Caddy gera certificado Let's Encrypt automático.
- [ ] Mosquitto com auth por username/password (não anônimo).
- [ ] Verificar: `curl https://vena-demo.duckdns.org/health` retorna 200.
- [ ] Verificar: `mosquitto_sub -h vena-demo.duckdns.org -p 8883 --capath /etc/ssl/certs -u demo -P xxx -t '#'` recebe mensagens.

### G. Build do APK de feira
- [ ] `flutter build apk --release --target=lib/main.dart` (apontando para backend de produção via `--dart-define=BACKEND_URL=https://vena-demo.duckdns.org`).
- [ ] Confirmar tamanho < 40 MB.
- [ ] Upload em GitHub Releases (tag `v1.0.0-feira`).
- [ ] Gerar QR code apontando para URL de download direto.
- [ ] Build paralela `main_mock` para fallback offline.

---

## Testes

| ID | Tipo | Descrição | Critério de sucesso |
|---|---|---|---|
| T12 | Unit | `DeviceActions.updateStoredContent` grava no Drift sem outbox entry | Coluna atualizada; `outbox` vazio |
| T13 | Widget | `StoredContentSelector` toggles entre 3 opções e revela TextField | `find.byType(TextField)` aparece só em modo "Outro" |
| T14 | Widget | `EditDeviceBottomSheet` salva alias + content | Provider chamado com valores corretos |
| T15 | Manual | App permanece tema claro com dark mode do SO ativado | Cards legíveis em qualquer device |
| T16 | Manual | 3 celulares conectados ao mesmo ESP32 via BLE recebendo notify | Telemetria ao vivo em todos sem queda |
| T17 | E2E | App de produção (URL VPS) recebe telemetria MQTT real do ESP32 físico | < 2s do publish ao card "Online" |
| T18 | Carga | Apache Bench `ab -n 500 -c 50 https://...../api/devices/X/telemetry` | p95 < 800ms, zero 5xx |

Smoke de integração T11 (BLE provisioning) deve continuar passando — sem regressão.

---

## Critérios de aceite (DoD)

1. **Funcional**:
   - App em release apontando para VPS de produção mostra telemetria ao vivo do ESP32 físico via MQTT.
   - Pareamento exibe seletor de conteúdo armazenado (Cacau / Pimenta / Outro / Pular).
   - Long-press em card da listagem abre bottom sheet de edição funcional.
   - Dark mode do SO **não** altera as cores do app.
   - 3 celulares conectam ao ESP32 via BLE ao mesmo tempo e recebem dados.

2. **Infra**:
   - `https://vena-demo.duckdns.org/health` responde 200 com TLS válido.
   - Mosquitto aceita conexões `mqtts://` (porta 8883) com auth.
   - Backups Supabase ativos (verificar painel).

3. **Testes**: T12–T18 verdes. Suite T1–T11 sem regressão.

4. **Distribuição**: QR code físico no stand aponta para APK universal funcional. APK de fallback (`vena-mock.apk`) em pen-drive.

---

## Armadilhas conhecidas

- **Supabase pooler vs direct**: usar a connection string do **pooler** (porta 6543, modo `transaction`) para FastAPI evitar esgotar as 200 conexões. A porta 5432 direta serve só para migrations.
- **Mosquitto + Caddy**: Caddy não faz proxy de TCP/MQTT nativo bem; expor Mosquitto diretamente na porta 8883 com certificado próprio (pode reutilizar o do Caddy via `tls_external_files`) é mais simples.
- **Oracle Always Free ARM**: imagens Docker `x86_64` falham silenciosamente. Garantir `--platform linux/arm64` ou imagens multi-arch (Mosquitto oficial tem; FastAPI build próprio precisa de `buildx`).
- **NimBLE 3 connections**: aumenta uso de RAM (~6 KB/conexão extra). Monitorar `ESP.getFreeHeap()` — se cair abaixo de 60 KB, reduzir para 2.
- **DuckDNS rate limit**: atualização de IP a cada 5 min só; se VPS reiniciar com IP novo, dar `curl` manual para o webhook DuckDNS.
- **APK universal pesa mais**: se ultrapassar 50 MB, gerar splits por ABI e disponibilizar arm64-v8a como principal (95% dos celulares atuais).
- **Long-press + Material InkWell**: o `Card` pode "comer" o gesto; use `InkWell(onLongPress: ...)` em vez de `GestureDetector` para feedback visual.
- **Migration Drift v2→v3**: se usuário fez beta-test com schema v2, garantir que `onUpgrade` é idempotente (`ifNotExists` na coluna).

---

## Ordem de execução recomendada

1. **A** (dark mode) — 30 min, libera testes manuais sem regressão visual.
2. **B** (campo conteúdo) — base para C; migration Drift primeiro.
3. **C** (edit long-press) — reusa widget de B.
4. **E** (Supabase) — independente; pode rodar em paralelo com A–C.
5. **F** (VPS + Docker) — depende de E (precisa do `DATABASE_URL`).
6. **D** (BLE multi-conn) — firmware-only; testar com APK de F já no ar.
7. **G** (APK de feira) — última etapa; confirma stack inteira de ponta a ponta.
8. T17 + T18 (carga) na VPS real antes da feira (idealmente 5 dias antes).

---

## Métricas de sucesso

- **Demo dia D**: ≥ 80% dos visitantes que escanearem o QR conseguem instalar, criar conta e ver dados ao vivo em < 2 min.
- **Uptime**: 100% durante as horas da feira (monitorar via `uptimerobot.com` free).
- **Latência MQTT→app**: < 3s p95 medido em campo.
- **Quedas BLE**: < 5% de tentativas de conexão falham.
- **Zero crashes** reportados via `flutter_error.log`.

---

## Dependências novas

- `package:flutter_riverpod` já presente.
- **Nenhuma** dependência Dart nova nesta fase (reusa Drift, Riverpod, mobile_scanner, flutter_reactive_ble já instalados).
- **Infra**:
  - Conta Supabase (gratuita).
  - Conta Oracle Cloud (gratuita, exige cartão sem cobrança).
  - DuckDNS (gratuito, login via GitHub).
  - GitHub Releases para hospedar APK (já existe).

---

## Escopo fora desta fase

- Sincronização de `storedContent` com backend (Postgres column + endpoint PATCH). Fica para Fase 6.
- TimescaleDB hypertables — adiar até migrar para Supabase Pro ou Postgres self-hosted.
- Dark mode "de verdade" com paleta orgânica — feedback pós-feira decide se vale o esforço.
- BLE bonding/criptografia em produção (Just Works ainda no MVP).
- CDN para APK (GitHub Releases serve bem o demo).
- Observabilidade (Grafana/Prometheus) — basta `docker logs` + `uptimerobot` para o demo.
- Onboarding tutorial in-app — fica para Fase 6 quando o produto for público.
