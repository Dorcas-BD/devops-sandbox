#!/bin/bash

INTERVAL=30
FAIL_THRESHOLD=3
declare -A FAIL_COUNT

log_health() {
  local ENV_ID=$1
  local STATUS=$2
  local LATENCY=$3
  mkdir -p "logs/${ENV_ID}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] status=$STATUS latency=${LATENCY}ms" >> "logs/${ENV_ID}/health.log"
}

while true; do
  for STATE_FILE in envs/*.json; do
    [ -f "$STATE_FILE" ] || continue
    ENV_ID=$(jq -r '.id' "$STATE_FILE")
    # get the port for this environment
    PORT=$(jq -r '.port' "$STATE_FILE")

    START=$(date +%s%N)
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:${PORT}/health" || echo "000")
    END=$(date +%s%N)
    LATENCY=$(( (END - START) / 1000000 ))

    log_health "$ENV_ID" "$HTTP_STATUS" "$LATENCY"

    if [ "$HTTP_STATUS" != "200" ]; then
      FAIL_COUNT[$ENV_ID]=$(( ${FAIL_COUNT[$ENV_ID]:-0} + 1 ))
      
      if [ "${FAIL_COUNT[$ENV_ID]}" -ge "$FAIL_THRESHOLD" ]; then
        echo "[WARNING] $ENV_ID is DEGRADED (${FAIL_COUNT[$ENV_ID]} consecutive failures)"
        # Update status in state file
        TMPFILE=$(mktemp)
        jq '.status = "degraded"' "$STATE_FILE" > "$TMPFILE" && mv "$TMPFILE" "$STATE_FILE"
      fi
    else
      FAIL_COUNT[$ENV_ID]=0
    fi
  done
  sleep "$INTERVAL"
done
