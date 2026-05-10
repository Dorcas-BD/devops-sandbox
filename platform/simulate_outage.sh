#!/bin/bash
set -euo pipefail

ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV_ID="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[ -z "$ENV_ID" ] && echo "Error: --env required" && exit 1
[ -z "$MODE" ] && echo "Error: --mode required" && exit 1

# Guard: never target nginx or daemon
if [[ "$ENV_ID" == "sandbox-nginx" || "$ENV_ID" == "sandbox-daemon" ]]; then
  echo "Error: cannot simulate against system containers." && exit 1
fi

STATE_FILE="envs/${ENV_ID}.json"
[ ! -f "$STATE_FILE" ] && echo "Error: env $ENV_ID not found" && exit 1
NETWORK=$(jq -r '.network' "$STATE_FILE")

case $MODE in
  crash)
    echo "[+] Crashing $ENV_ID..."
    docker kill "$ENV_ID"
    ;;
  pause)
    echo "[+] Pausing $ENV_ID..."
    docker pause "$ENV_ID"
    ;;
  network)
    echo "[+] Disconnecting $ENV_ID from network..."
    docker network disconnect "$NETWORK" "$ENV_ID"
    ;;
  recover)
    echo "[+] Recovering $ENV_ID..."
    docker unpause "$ENV_ID" 2>/dev/null || true
    docker start "$ENV_ID" 2>/dev/null || true
    docker network connect "$NETWORK" "$ENV_ID" 2>/dev/null || true
    TMPFILE=$(mktemp)
    jq '.status = "running"' "$STATE_FILE" > "$TMPFILE" && mv "$TMPFILE" "$STATE_FILE"
    ;;
  stress)
    echo "[+] Stressing CPU on $ENV_ID..."
    docker exec "$ENV_ID" sh -c "apt-get install -y stress-ng -q && stress-ng --cpu 2 --timeout 30s" &
    ;;
  *)
    echo "Unknown mode: $MODE. Use crash|pause|network|recover|stress"
    exit 1
    ;;
esac

echo "[+] Simulation '$MODE' applied to $ENV_ID."
