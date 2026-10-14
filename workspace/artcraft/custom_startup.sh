#!/usr/bin/env bash
set -Eeuo pipefail
/usr/bin/desktop_ready
LOG_DIR="$HOME/.local/state/artcraft"
mkdir -p "$LOG_DIR"
LAUNCHER="$(cat /etc/artcraft-launcher-path)"
[[ -x "$LAUNCHER" ]] || { echo "Missing launcher: $LAUNCHER" >&2; exit 1; }
if [[ "${ARTCRAFT_SOFTWARE_RENDERING:-0}" == 1 ]]; then
    export LIBGL_ALWAYS_SOFTWARE=1
fi
nohup "$LAUNCHER" > "$LOG_DIR/launcher.log" 2>&1 < /dev/null &
PID=$!
if [[ "${ARTCRAFT_FULLSCREEN:-1}" != 1 ]]; then exit 0; fi
for ((i=0; i<60; i++)); do
    WINDOWS="$(wmctrl -lp || true)"
    ID="$(awk -v pid="$PID" '$3 == pid {print $1; exit}' <<< "$WINDOWS")"
    if [[ -z "$ID" ]]; then
        ID="$(awk 'tolower($0) ~ /artcraft.*launcher|craft.*launcher/ {print $1; exit}' <<< "$WINDOWS")"
    fi
    if [[ -n "$ID" ]]; then
        wmctrl -i -a "$ID" || true
        wmctrl -i -r "$ID" -b add,fullscreen || true
        exit 0
    fi
    sleep 1
done
echo 'No launcher window identified within 60 seconds.' >> "$LOG_DIR/launcher.log"
wmctrl -lp >> "$LOG_DIR/launcher.log" || true
