#!/bin/bash
set -euo pipefail #stop the script immediately if any command fail
# -e = exit on error, -u = error on undefined variables, -o = pipefail = ![Architecture](architecture.png) 

NAME=${1:-"env"} # first argument passed to the script becomes the name, if no argument given, default to "env"
# second argument is the TTL (time to live) in seconds, default is 1800 seconds = 30 minutes
TTL=${2:-1800}

ENV_ID="env-$(openssl rand -hex 4)" #generate random unique env
NETWORK="${ENV_ID}-net" #name the docker network after the env
PORT=$(shuf -i 9000-9999 -n 1) # pick a random port between 9000 and 9999, so each environment gets its own port and they don't clash
STATE_FILE="envs/${ENV_ID}.json" # where info about this environment are saved
NGINX_CONF="nginx/conf.d/${ENV_ID}.conf" # where the nginx config for this environment are written

echo "[+] Creating environment: $ENV_ID (name=$NAME, TTL=${TTL}s)"

docker network create "$NETWORK" # create a private Docker network just for this environment

docker run -d \
    --name "$ENV_ID" \
    --network "$NETWORK" \
    -e ENV_ID="$ENV_ID" \
    -l "sandbox.env=$ENV_ID" \
    -p "${PORT}:8080" \
    sandbox-demo-app:latest

# upstream tells nginx where the app is
cat > "$NGINX_CONF" <<EOF
upstream ${ENV_ID} { 
    server 127.0.0.1:${PORT};
}
server {
    listen 80;
    server_name ${ENV_ID}.localhost;
    location / {
        proxy_pass http://${ENV_ID}
        proxy_set_header Host \$host
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Reload nginx
docker exec sandbox-nginx nginx -s reload 2>/dev/null || true


CREATED_AT=$(date +%s) 
TMPFILE=$(mktemp)
cat > "$TMPFILE" <<EOF
{
  "id": "$ENV_ID",
  "name": "$NAME",
  "created_at": $CREATED_AT,
  "ttl": $TTL,
  "port": $PORT,
  "status": "running",
  "network": "$NETWORK"
}
EOF
mv "$TMPFILE" "$STATE_FILE"
# atomically move the temp file to the real location
# "atomic" means it either fully exists or doesn't, no in-between

# Start log shipping
mkdir -p "logs/${ENV_ID}"
docker logs -f "$ENV_ID" >> "logs/${ENV_ID}/app.log" 2>&1 &
echo $! > "logs/${ENV_ID}/logger.pid"

echo ""
echo "Environment URL: http://${ENV_ID}.localhost (or http://localhost:${PORT})"
echo "TTL: ${TTL}s (~$((TTL/60)) min)"
echo "ENV_ID: $ENV_ID"
