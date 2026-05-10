#!/bin/bash

LOGFILE="logs/cleanup.log"
mkdir -p logs

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "Cleanup daemon started."

#loops forever
while true; do 
  NOW=$(date +%s)
  for STATE_FILE in envs/*.json; do # loop through every environment state file
    [ -f "$STATE_FILE" ] || continue
    ENV_ID=$(jq -r '.id' "$STATE_FILE")
    CREATED_AT=$(jq -r '.created_at' "$STATE_FILE")
    TTL=$(jq -r '.ttl' "$STATE_FILE")
    EXPIRES_AT=$(( CREATED_AT + TTL )) # calculate when this environment should die

    if [ "$NOW" -ge "$EXPIRES_AT" ]; then
      log "TTL expired for $ENV_ID. Destroying..."
      bash platform/destroy_env.sh "$ENV_ID" >> "$LOGFILE" 2>&1
      log "Destroyed $ENV_ID."
    fi
  done
   # wait 60 seconds before checking again
  sleep 60
done
