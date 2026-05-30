# =============================================================================
# Vena Backend — Dockerfile
# Build: docker build -t vena-fastapi:prod ./backend
# Plataforma alvo: linux/amd64 (Azure B2s)
# =============================================================================

# --------------- Etapa 1: dependências (layer cacheada) ---------------------
FROM python:3.11-slim AS deps

WORKDIR /app

# Instala apenas o necessário para compilar wheels nativas (asyncpg, cryptography)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libffi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml .

# Instala dependências de produção (sem extras dev) em um diretório isolado
RUN pip install --no-cache-dir --prefix=/install ".[standard]" 2>/dev/null || \
    pip install --no-cache-dir --prefix=/install \
        fastapi \
        "uvicorn[standard]" \
        paho-mqtt \
        "sqlalchemy[asyncio]" \
        asyncpg \
        alembic \
        pydantic \
        pydantic-settings \
        "python-jose[cryptography]" \
        bcrypt \
        google-auth \
        requests \
        python-multipart \
        httpx \
        loguru

# --------------- Etapa 2: imagem final enxuta --------------------------------
FROM python:3.11-slim

WORKDIR /app

# Copia dependências compiladas
COPY --from=deps /install /usr/local

# Copia código fonte
COPY . .

# Usuário não-root por segurança
RUN useradd -m -u 1001 vena && chown -R vena:vena /app
USER vena

EXPOSE 8000

# Inicia com Uvicorn; número de workers = 1 é suficiente para IoT demo.
# Aumentar para 2-4 se a carga justificar (RAM do B2s: 4 GB).
CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "1", \
     "--log-level", "info"]
