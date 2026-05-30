#!/usr/bin/env bash
# =============================================================================
# Vena — bootstrap de VM de produção (Azure B2s, Ubuntu 22.04 LTS, amd64)
# Execute UMA VEZ como root imediatamente após provisionar a VM:
#
#   curl -fsSL https://raw.githubusercontent.com/<seu-repo>/main/scripts/bootstrap_vm.sh | sudo bash
#
# Ou copie o script para a VM e rode:
#   chmod +x bootstrap_vm.sh && sudo ./bootstrap_vm.sh
# =============================================================================
set -euo pipefail

VENA_DIR="/opt/vena"
REPO_URL="${REPO_URL:-}"  # defina antes de rodar ou edite abaixo
DOMAIN="${DOMAIN:-vena-demo.duckdns.org}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN:-}"  # token do DuckDNS

echo "==> [1/7] Atualizando pacotes base"
apt-get update -qq && apt-get upgrade -y -qq

echo "==> [2/7] Instalando dependências"
apt-get install -y -qq \
    curl git ca-certificates gnupg lsb-release ufw fail2ban

echo "==> [3/7] Instalando Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

echo "==> [4/7] Configurando firewall (UFW)"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp    # Caddy ACME challenge + redirect
ufw allow 443/tcp   # HTTPS
ufw allow 8883/tcp  # MQTT/TLS
ufw --force enable

echo "==> [5/7] Configurando DuckDNS (atualização de IP a cada 5 min)"
if [[ -z "$DUCKDNS_TOKEN" ]]; then
    echo "  AVISO: DUCKDNS_TOKEN não definido — pule este passo e configure manualmente."
else
    DUCKDNS_SUBDOMAIN="${DOMAIN%%.*}"   # extrai "vena-demo" de "vena-demo.duckdns.org"
    DUCKDNS_SCRIPT="/opt/duckdns/duck.sh"
    mkdir -p /opt/duckdns

    cat > "$DUCKDNS_SCRIPT" <<EOF
#!/bin/bash
curl -fsSL "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=" \
    -o /opt/duckdns/duck.log 2>&1
EOF
    chmod +x "$DUCKDNS_SCRIPT"

    # Cron a cada 5 minutos
    (crontab -l 2>/dev/null; echo "*/5 * * * * $DUCKDNS_SCRIPT") | crontab -
    echo "  DuckDNS configurado para domínio ${DOMAIN}"
fi

echo "==> [6/7] Clonando repositório em $VENA_DIR"
if [[ -n "$REPO_URL" ]]; then
    git clone "$REPO_URL" "$VENA_DIR"
else
    mkdir -p "$VENA_DIR"
    echo "  AVISO: REPO_URL não definido. Copie os arquivos manualmente para $VENA_DIR"
    echo "         e coloque o .env.prod na raiz do projeto."
fi

echo "==> [7/7] Instruções finais"
cat <<'EOF'

  Próximos passos manuais:
  ────────────────────────
  1. Copie (ou crie) o arquivo .env.prod em /opt/vena/.env.prod
     com DATABASE_URL, JWT_SECRET, PAIRING_SECRET, etc.

  2. Edite /opt/vena/infra/Caddyfile e /opt/vena/infra/mosquitto/mosquitto.prod.conf
     substituindo "vena-demo.duckdns.org" pelo seu domínio real.

  3. Suba os containers:
       cd /opt/vena
       docker compose -f infra/docker-compose.prod.yml --env-file .env.prod up -d

  4. Acompanhe os logs:
       docker compose -f infra/docker-compose.prod.yml logs -f

  5. Verifique saúde:
       curl https://vena-demo.duckdns.org/health

  6. Aguarde o Caddy obter o certificado Let's Encrypt (~30 s).
     Logs do Caddy: docker compose logs caddy

  Portas abertas na VM:
    22    SSH
    80    HTTP (redirect → HTTPS)
    443   HTTPS (FastAPI via Caddy)
    8883  MQTT/TLS (Mosquitto direto)

EOF

echo "Bootstrap concluído."
