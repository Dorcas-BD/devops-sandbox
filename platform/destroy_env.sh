#!/bin/bash
set -euo pipefail

ENV_ID=${1:?"Usage: destroy_env.sh <ENV_ID>"}
STATE_FILE="envs/${ENV_ID}.json"
NGINX_CONF="nginx/conf.d/${ENV_ID}.conf"

echo "[+] Destroying environment: $ENV_ID"

# Kill log shipper
LOGGER_PID_FILE="logs/${ENV_ID}/logger.pid"
if [ -f "$LOGGER_PID_FILE" ]; then
  kill "$(cat "$LOGGER_PID_FILE")" 2>/dev/null || true
  rm -f "$LOGGER_PID_FILE"
fi

# Stop and remove container
docker stop "$ENV_ID" 2>/dev/null || true
docker rm "$ENV_ID" 2>/dev/null || true

# Remove network
NETWORK="${ENV_ID}-net"
docker network rm "$NETWORK" 2>/dev/null || true

# Remove nginx config and reload
rm -f "$NGINX_CONF"
docker exec sandbox-nginx nginx -s reload 2>/dev/null || true

# Archive the logs before deleting them
mkdir -p "logs/archived/${ENV_ID}"
cp -r "logs/${ENV_ID}/." "logs/archived/${ENV_ID}/" 2>/dev/null || true
rm -rf "logs/${ENV_ID}"

# Remove state file, env is goneeee
rm -f "$STATE_FILE"

echo "[+] Environment $ENV_ID destroyed."
