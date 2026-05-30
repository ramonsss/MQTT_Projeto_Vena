# Fase 5 — Agregação, Produção e Beta de Campo

> **Objetivo**: Fechar o ciclo de produção. Implementar agregação temporal (1m/1h/1d), endpoint `/history` com bucket adaptativo, monitoramento básico e validação com dispositivos reais em campo.
>
> **Pré-requisito**: Fase 4.5 concluída (deploy em produção Azure + Supabase funcionando, app release com dark mode forçado, BLE multi-conn, edição long-press). Stack `https://vena-demo.duckdns.org` no ar com HTTPS válido.

---

## Contexto novo trazido pela Fase 4.5

O plano original assumia TimescaleDB self-hosted. A 4.5 mudou três premissas críticas:

| Item | Plano original | Realidade pós-4.5 | Consequência para Fase 5 |
|---|---|---|---|
| Banco | TimescaleDB self-hosted | Supabase Postgres puro | Sem `create_hypertable`, sem continuous aggregates, sem `add_retention_policy` |
| Retention | Policy automática TimescaleDB | `pg_cron` agendado (migration `b2`) | Cleanup já implementado |
| Agregação | Continuous aggregates | Precisa ser **pull-based** (query agrega na hora) ou **push-based** (job Python materializa) | Decisão de design abaixo |
| Deploy | "Fase 5 entrega o deploy" | Já no ar (Azure VM + Caddy + Mosquitto + FastAPI) | Sobra orçamento para monitoramento e robustez |
| Schema mobile | Drift v1 | Drift v2 com `storedContent` | Backend ainda não conhece esse campo — débito documentado |
| BLE | 1 conexão | 3 conexões simultâneas | Mais carga em RAM do ESP32 — monitorar em campo |

---

## Decisões técnicas (resolver ANTES de codificar)

| # | Decisão | Resolução |
|---|---------|-----------|
| 1 | **Agregação: pull ou push?** | **Pull-based** (query SQL com `date_trunc` + agregações on-demand). Volume da feira é trivial (<200K linhas), `device_id + ts` index resolve em <100ms. Sem materialização. Push-based fica para Fase 6 quando volume justificar. |
| 2 | **Buckets disponíveis no `/history`** | `5s` (raw, máx 24h), `1m` (até 7d), `1h` (até 90d), `1d` (até 1y). Backend escolhe automaticamente baseado em `range` se cliente não especificar. |
| 3 | **Agregações expostas** | `avg`, `min`, `max` para `ambient_t`, `ambient_h`, `diss_t`, `diss_h`. `setpoint` e `pid_out` só `avg`. `sample_count` sempre incluído. |
| 4 | **Cache de agregados no app** | Drift table `history_cache` com TTL 5min por `(device_id, bucket, range)`. Invalida ao receber telemetria nova com `ts > cache.max_ts`. |
| 5 | **Monitoramento da VM** | UptimeRobot free (HTTP check `/health` a cada 5min) + log do `docker stats` em arquivo rotativo. Sem Grafana/Prometheus — over-engineering para a feira. |
| 6 | **Limite de heap no ESP32** | Logar `ESP.getFreeHeap()` no `meta` a cada boot. Alerta no app se < 60 KB (3 BLE conns + Wi-Fi + buffers consomem ~25 KB extra vs single-conn). |
| 7 | **Sync `storedContent` com backend** | **Fora de escopo**. Permanece como débito. Backend não sabe desse campo; apenas Drift local. |
| 8 | **Beta de campo** | 3 unidades Vena em locais reais (casa do dev, jardim do mentor, sala do orientador). Coletar 5 dias de telemetria contínua antes da feira. Monitorar uptime, gaps de offline buffer, comportamento BLE. |
| 9 | **Backup do Supabase** | Free tier já faz backup diário automático (7 dias de retenção). Validar uma restauração manual de teste em projeto Supabase temporário. |
| 10 | **Plano de rollback no dia da feira** | Tag git `v1.0.0-feira` congelada 48h antes. Se algo quebrar, `git checkout v1.0.0-feira && docker compose up -d --build`. APK de fallback `vena-mock.apk` no pen-drive físico. |

---

## Reflexões respondidas (opinião direta)

### A. "Vale a pena materializar agregados sem TimescaleDB?"
**Não para o demo.** Materializar via `pg_cron` + `MATERIALIZED VIEW REFRESH` no Supabase free é viável mas tem custo de complexidade alto para benefício zero no volume da feira:
- 3 devices × 17K linhas/dia × 5 dias = ~255K linhas
- Query `SELECT date_trunc('hour', ts), avg(ambient_t) FROM telemetry_raw WHERE device_id=X AND ts > now() - interval '7 days' GROUP BY 1` com índice composto roda em <50ms
- Vantagem de view materializada só aparece em >10M linhas ou >100 reqs/s

Decisão: **pull-based agora**, push-based vira tarefa documentada para Fase 6 quando houver carga real.

### B. "Preciso de Grafana ou observabilidade séria?"
**Não.** Para a feira:
- **UptimeRobot free**: avisa por e-mail/SMS se `https://vena-demo.duckdns.org/health` cair
- **Logs do Docker**: `docker compose logs -f --tail=100` já mostra tudo
- **Painel SQL do Supabase**: você abre o navegador e mostra `SELECT count(*) FROM telemetry_raw WHERE ts > now() - interval '1 hour'` ao vivo durante apresentação (efeito impressionante)

Grafana exigiria mais 2 containers + configuração de dashboards + manutenção. Não cabe no escopo.

### C. "O beta de campo é realmente necessário?"
**Sim, é a parte mais subestimada do MVP.** Bugs que só aparecem após dias rodando:
- ESP32 trava silenciosamente após ~3 dias por leak de heap (já vimos isso em projetos similares)
- Wi-Fi reconnect loop em redes com captive portal
- Buffer offline enche quando Wi-Fi cai por >2h
- Drift do RTC sem NTP frequente

Sem 5 dias de runtime real, você descobre esses problemas **na feira** — pior cenário possível.

---

## Contratos

### Endpoint `GET /devices/{id}/history` — versão expandida

**Query params**:
```
range:  string  enum["1h","6h","24h","7d","30d","90d","1y"]  default="24h"
bucket: string  enum["auto","5s","1m","1h","1d"]              default="auto"
metric: string  comma-separated, default="all"
                 values: ambient_t, ambient_h, diss_t, diss_h, setpoint, pid_out
```

**Auto-bucket logic**:
```python
def choose_bucket(range_: str) -> str:
    return {
        "1h":  "5s",
        "6h":  "5s",
        "24h": "1m",
        "7d":  "1h",
        "30d": "1h",
        "90d": "1d",
        "1y":  "1d",
    }[range_]
```

**Response shape** (mudança incremental — campo `bucket` + agregados):
```json
{
  "device_id": "vena-a0b...",
  "bucket": "1h",
  "range_start": "2026-05-23T00:00:00Z",
  "range_end":   "2026-05-30T00:00:00Z",
  "samples": [
    {
      "ts": "2026-05-23T00:00:00Z",
      "ambient_t_avg": 22.4, "ambient_t_min": 20.1, "ambient_t_max": 24.8,
      "ambient_h_avg": 65.2, "ambient_h_min": 60.0, "ambient_h_max": 70.5,
      "diss_t_avg": 18.3,    "diss_t_min": 17.0,    "diss_t_max": 19.8,
      "diss_h_avg": 62.0,    "diss_h_min": 58.0,    "diss_h_max": 65.0,
      "setpoint_avg": 18.0,
      "pid_out_avg": 120.5,
      "sample_count": 720
    }
  ]
}
```

Quando `bucket="5s"` (raw), os campos `*_min/_max` são `null` e `*_avg` recebe o valor único da amostra (compatibilidade com schema atual).

### SQL query template (pull-based, sem TimescaleDB)

```sql
SELECT
    date_trunc(:bucket, ts) AS bucket,
    AVG(ambient_t) AS ambient_t_avg,
    MIN(ambient_t) AS ambient_t_min,
    MAX(ambient_t) AS ambient_t_max,
    -- ... idem para outros campos
    COUNT(*) AS sample_count
FROM telemetry_raw
WHERE device_id = :device_id
  AND ts >= :start
  AND ts <  :end
GROUP BY 1
ORDER BY 1;
```

`date_trunc` aceita `'second'`, `'minute'`, `'hour'`, `'day'`. Para `5s` (sub-segundo) cai no path raw sem GROUP BY.

### Drift — nova tabela `history_cache`

```dart
class HistoryCache extends Table {
  TextColumn  get deviceId   => text()();
  TextColumn  get bucket     => text()();   // '5s'|'1m'|'1h'|'1d'
  TextColumn  get range      => text()();   // '24h'|'7d'|...
  TextColumn  get payload    => text()();   // JSON serializado da response
  IntColumn   get fetchedAt  => integer()();
  IntColumn   get maxTs      => integer()(); // ts mais recente no payload
  @override Set<Column> get primaryKey => {deviceId, bucket, range};
}
```

Migration v2 → v3 no Drift.

Invalidação: trigger no insert de `LatestState` — se `newTs > cache.maxTs`, deletar a row do cache.

### ESP32 — payload `meta` expandido

`vena/{deviceId}/meta` (retain=true, publicado no boot):
```json
{
  "fw_version": "1.0.0-feira",
  "ble_max_conn": 3,
  "free_heap_boot": 142336,
  "free_heap_min_runtime": 98420,
  "wifi_rssi": -62,
  "ntp_synced": true,
  "boot_count": 17,
  "last_reset_reason": "ESP_RST_POWERON"
}
```

`free_heap_min_runtime` é o piso desde o último boot (rastreia degradação). Backend grava cada `meta` em tabela `device_events` para auditoria de campo.

---

## Checklist de implementação

### A. Backend — agregação on-the-fly (~3h)
- [ ] Em `backend/app/telemetry/service.py`, criar `get_device_history_aggregated(session, device_id, range, bucket, metrics)`.
  - Validar `range` e `bucket` contra enums.
  - Calcular `start = now() - parse_range(range)`.
  - Se `bucket == "5s"` → reusa query raw existente.
  - Senão → query com `date_trunc(:bucket, ts)` + `AVG/MIN/MAX/COUNT`.
- [ ] Estender `HistoryResponse` schema com campos `bucket`, `range_start`, `range_end` e amostras agregadas.
- [ ] Atualizar `routes.py`: aceitar `range`, `bucket`, `metric` em vez de `start`/`end`/`limit`.
- [ ] Manter retrocompatibilidade: se `start` e `end` forem passados, comportar como hoje.
- [ ] Testes em `backend/tests/test_history.py` cobrindo cada bucket.

### B. Backend — endpoint `meta` (~1h)
- [ ] No `MqttWorker`, adicionar handler para tópico `vena/+/meta` (já recebido pela subscrição wildcard).
- [ ] Em `telemetry/ingest.py`, separar parsing: telemetria vai para `telemetry_raw`, meta vai para nova tabela `device_meta` (UPSERT por `device_id`, sempre o último).
- [ ] Drift migration backend: nova tabela `device_meta` (device_id PK, payload JSONB, updated_at).
- [ ] Endpoint `GET /devices/{id}/meta` para o app consultar.

### C. Firmware — meta payload (~2h)
- [ ] Em `firmware/src/main.cpp`, criar função `publish_meta()` chamada no `setup()` após MQTT connect.
- [ ] Tracking de `free_heap_min_runtime`: variável global atualizada a cada `loop()` (não no momento do publish — captura piso real).
- [ ] Incrementar `boot_count` via NVS (RTC RAM persiste reset; NVS persiste reflash).
- [ ] Reusar `esp_reset_reason()` para `last_reset_reason`.
- [ ] Publicar JSON com `retain=true`, QoS 1.

### D. Mobile — `/history` consumindo agregado (~3h)
- [ ] Em `mobile/lib/core/network/`, atualizar `HistoryApi.fetch(deviceId, range, bucket)`.
- [ ] Drift schema v3: adicionar `HistoryCache` table + migration.
- [ ] Provider `historyProvider(deviceId, range)` lê cache primeiro; refetch se >5min.
- [ ] Trigger de invalidação ao receber novo `LatestState`.
- [ ] Em `features/history/presentation/`, adicionar seletor de range (chips: `1h`/`24h`/`7d`/`30d`).
- [ ] Gráfico `fl_chart` renderiza `*_avg` como linha principal e `*_min`/`*_max` como banda sombreada (gradient fill).

### E. Beta de campo (5 dias antes da feira)
- [ ] Configurar 3 ESP32 com firmware release.
- [ ] Distribuir: 1 na casa do dev, 1 com mentor, 1 com orientador.
- [ ] Cada device com cabo de alimentação confiável (USB no PC ou fonte 5V/2A — **não** powerbank, descarrega).
- [ ] Monitorar diariamente via app:
  - Telemetria contínua (gap < 2min em 24h)
  - Free heap não decresce (sem leak)
  - BLE conecta no primeiro try (>95% de sucesso)
  - Offline buffer preserva dados durante quedas Wi-Fi
- [ ] Coletar bugs em issues do repo com label `beta-feira`.

### F. Monitoramento de produção (~1h)
- [ ] Cadastrar `https://vena-demo.duckdns.org/health` no UptimeRobot (free).
- [ ] Configurar alerta por e-mail se ficar `down` por >5min.
- [ ] Criar script `scripts/check_health.sh` que roda no cron da VM a cada 1h e loga `docker stats` + `df -h` em `/var/log/vena-health.log`.
- [ ] Configurar logrotate em `/var/log/vena-health.log` (max 50MB, 7 dias).

### G. Painel SQL para demo (~30min)
- [ ] No painel Supabase → **SQL Editor**, salvar queries prontas:
  - `Telemetria última hora`: `SELECT device_id, count(*), max(ts) FROM telemetry_raw WHERE ts > now() - interval '1 hour' GROUP BY 1;`
  - `Throughput por minuto`: `SELECT date_trunc('minute', ts), count(*) FROM telemetry_raw WHERE ts > now() - interval '1 hour' GROUP BY 1 ORDER BY 1 DESC LIMIT 30;`
  - `Devices online`: `SELECT id, status, last_seen_at FROM devices ORDER BY last_seen_at DESC;`
- [ ] Testar com browser em projetor antes da feira.

### H. Hardening final (~2h)
- [ ] Validar `https://vena-demo.duckdns.org` em Qualys SSL Labs — alvo: nota **A** ou melhor.
- [ ] Configurar `fail2ban` para SSH na VM (já instalado pelo bootstrap, só ativar com `sudo systemctl enable --now fail2ban`).
- [ ] Reset de senhas: rotacionar `JWT_SECRET` e `PAIRING_SECRET` no `.env.prod`, redeploy.
- [ ] Tag git `v1.0.0-feira` quando passar T19–T23.
- [ ] Backup manual do Supabase: `Settings → Database → Backups → Restore` em projeto teste para validar fluxo.

---

## Testes

| ID | Tipo | Descrição | Critério de sucesso |
|---|---|---|---|
| T19 | Unit | `choose_bucket("24h") == "1m"`, `choose_bucket("7d") == "1h"`, ... | Todos os mapeamentos corretos |
| T20 | Integration | `GET /devices/{id}/history?range=24h` retorna array de 1440 buckets de 1min | Status 200, schema válido, contagem correta |
| T21 | Integration | `GET /devices/{id}/meta` retorna o último meta publicado | Campos `free_heap_min_runtime`, `boot_count` presentes |
| T22 | Widget | Seletor de range no app troca dados do gráfico | `find.text('7 dias')` tap → API chamada com `range=7d` |
| T23 | Manual (beta) | 5 dias de runtime contínuo em campo | Uptime app ≥ 95%, sem crashes, free heap estável |
| T24 | Carga | `ab -n 200 -c 20 https://.../devices/X/history?range=7d` | p95 < 1.5s, zero 5xx |
| T25 | Manual | Restaurar backup do Supabase em projeto teste | Tabelas íntegras, contagens batem com original |

---

## Critérios de aceite (DoD)

1. **Funcional**:
   - `GET /history?range=24h` retorna buckets de 1min com avg/min/max.
   - App tem seletor de range visual com 4 opções (1h/24h/7d/30d).
   - ESP32 publica `meta` no boot; app consegue ver via `GET /devices/{id}/meta`.
   - 3 unidades rodaram 5 dias em campo sem intervenção manual.

2. **Infra**:
   - UptimeRobot monitorando, alertas configurados.
   - `fail2ban` ativo na VM.
   - SSL Labs grade A para `vena-demo.duckdns.org`.
   - Backup do Supabase restaurado com sucesso em ambiente teste.

3. **Testes**: T19–T25 verdes. Suite T1–T18 sem regressão.

4. **Documentação**: README do repositório atualizado com URL de produção, instruções de demo e link para o `docs/deploy-guia-completo.md`.

5. **Tag**: `v1.0.0-feira` apontando para commit congelado 48h antes da feira.

---

## Armadilhas conhecidas

- **`date_trunc` no asyncpg**: o `:bucket` precisa ser **literal string**, não parâmetro (`date_trunc` é função imutável e o asyncpg trata parâmetros como bytes). Solução: validar contra enum no Python e interpolar via f-string seguro (`f"date_trunc('{bucket}', ts)"`) após validação estrita.
- **Cache de history no app**: invalidar SÓ quando `newTs > cache.maxTs` — se invalidar a cada nova amostra, o app refaz a query do gráfico a cada 5s, péssimo.
- **`fl_chart` com banda min/max**: precisa de dois `LineChartBarData` separados (um para `_min`, um para `_max`) com `belowBarData` para preencher entre eles. Documentação confusa — testar em um exemplo isolado primeiro.
- **NTP no ESP32**: se `configTime` falhar, `time(nullptr)` retorna 0; `ts=0` polui o gráfico. Validar com `if (time(nullptr) > 1600000000)` antes de publicar.
- **UptimeRobot false-positives**: se sua VM ficar atrás de Cloudflare ou proxy, configurar header `Host` correto. Para Caddy direto não tem esse problema.
- **Beta de campo + powerbank**: ESP32 com Wi-Fi acordado consome ~150 mA. Powerbank 10000 mAh aguenta ~60h, mas a maioria entra em modo standby por baixa corrente. Usar fonte fixa.
- **`device_meta` UPSERT**: usar `INSERT ... ON CONFLICT (device_id) DO UPDATE SET ...` para não acumular row a cada boot.
- **Supabase free tier — 500MB**: 3 devices × 5 dias × ~3.5 MB/device/dia = ~52 MB. Folga grande, mas se a feira esticar para 30 dias, vira ~315 MB. Sem problema.

---

## Ordem de execução recomendada

1. **A** (agregação backend) — base de tudo; sem isso o app não tem o que renderizar.
2. **B** + **C** (meta endpoint + firmware) — paralelo; podem ser feitos em sessões independentes.
3. **D** (mobile history) — depende de A.
4. **F** (monitoramento) — pode ser feito a qualquer momento; idealmente cedo para já capturar regressões.
5. **G** (painel SQL) — quick win, fazer assim que o backend estiver estável.
6. **E** (beta de campo) — **começar o mais cedo possível** (precisa de 5 dias úteis antes da feira).
7. **H** (hardening) — última semana, congelamento 48h antes.

---

## Métricas de sucesso

- **Uptime durante a feira**: 100% (UptimeRobot deve mostrar verde contínuo).
- **Latência `/history?range=24h`**: p95 < 800ms.
- **Drift de relógio ESP32 vs servidor**: < 2s após 24h (validar com `ts` da telemetria vs `created_at` do banco).
- **Beta — gaps de telemetria**: < 0.5% das amostras esperadas em 5 dias.
- **Beta — crashes do firmware**: 0 reboots não-intencionais (boot_count só sobe por desligar fonte).
- **Demo dia D — segurança**: nenhum alerta de cert TLS no celular dos visitantes.

---

## Dependências novas

**Backend** (em `pyproject.toml`):
- Nenhuma — `sqlalchemy` + `asyncpg` já cobrem `date_trunc` via raw SQL.

**Mobile** (em `pubspec.yaml`):
- `intl: ^0.19.0` — formatação de datas no seletor de range (provavelmente já presente).

**Firmware**:
- Nenhuma — `Preferences.h` (NVS) já está no Arduino core ESP32.

**Infra**:
- Conta UptimeRobot (gratuita, 50 monitores).

---

## Escopo fora desta fase

- **Sincronização de `storedContent` com backend** — débito da 4.5, fica para Fase 6.
- **Continuous aggregates / materialized views** — só justifica acima de 10M linhas.
- **TimescaleDB no Supabase Pro** — adiar; ROI baixo para o volume atual.
- **Notificações push de thresholds** — Fase 6.
- **App admin web** — Fase 6.
- **Multi-tenancy organizacional** — Fase 7.
- **OTA firmware via MQTT** — Fase 7.
- **Edge gateway (Raspberry local)** — só se feedback de feira mostrar Wi-Fi precária recorrente.
