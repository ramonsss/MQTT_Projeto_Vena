# Vena

Plataforma IoT offline-first para monitoramento de temperatura e umidade por produtores rurais.

Cada unidade **Vena** é um ESP32 com sensores DHT22. O app Flutter monitora localmente via BLE e remotamente via MQTT. O backend Python persiste telemetria em PostgreSQL.

---

## Estrutura do repositório

```
.
├── firmware/       # ESP32 (PlatformIO)
├── backend/        # FastAPI + Paho MQTT + PostgreSQL
├── mobile/         # Flutter (a implementar)
├── infra/          # Docker Compose (Postgres + Mosquitto)
└── .env.example    # Template de variáveis de ambiente
```

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Python | 3.11 |
| Docker + Docker Compose | 24 |
| PlatformIO CLI | 6 |
| Flutter SDK | 3.22 |

---

## 1. Variáveis de ambiente

Copie o template na raiz do projeto e preencha os valores:

```sh
cp .env.example .env
```

O `.env` é lido pelo backend Python **e** pelo Docker Compose. Nunca o commite.

---

## 2. Subir a infraestrutura (Postgres + Mosquitto)

```sh
cd infra
docker compose up -d
```

Serviços iniciados:

| Serviço | Porta |
|---|---|
| PostgreSQL (TimescaleDB) | `5432` |
| Mosquitto MQTT (TCP) | `1883` |
| Mosquitto MQTT (WebSocket) | `9001` |

Para parar:

```sh
docker compose down
```

Para parar e apagar os dados:

```sh
docker compose down -v
```

---

## 3. Backend (FastAPI)

### Instalar dependências

```sh
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux / macOS
source venv/bin/activate

pip install -e ".[dev]"
```

### Criar e aplicar as migrations

Necessário uma vez após subir o Postgres pela primeira vez, e sempre que houver mudança nos models:

```sh
# Gerar migration a partir dos models
alembic revision --autogenerate -m "descrição"

# Aplicar ao banco
alembic upgrade head
```

### Rodar o servidor

```sh
uvicorn app.main:app --reload
```

API disponível em `http://localhost:8000`.  
Documentação interativa em `http://localhost:8000/docs`.

### Verificar saúde

```sh
curl http://localhost:8000/health
# {"status":"ok","service":"vena-backend"}
```

---

## 4. Firmware (ESP32)

### Configurar credenciais locais

Crie o arquivo `firmware/platformio.local.ini` (ignorado pelo git):

```ini
[env:esp32dev]
build_flags =
    -DWIFI_SSID=\"SuaRedeWifi\"
    -DWIFI_PASSWORD=\"SuaSenha\"
    -DMQTT_HOST=\"192.168.x.x\"
```

### Compilar e gravar

```sh
cd firmware
pio run --target upload
```

### Monitor serial

```sh
pio device monitor
```

---

## 5. Testes

```sh
cd backend
pytest
```

```sh
cd firmware
pio test
```

---

## Fluxo de dados (resumo)

```
ESP32 ──MQTT──▶ Mosquitto ──▶ Backend (Paho worker) ──▶ PostgreSQL
                    │
                    └──MQTT──▶ App Flutter (direto, JWT auth)
```

A UI do app sempre lê do SQLite local. BLE, MQTT e REST apenas alimentam o cache.
