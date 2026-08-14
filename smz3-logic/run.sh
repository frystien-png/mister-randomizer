#!/bin/sh
# Starts the logic service. Runs as CMD in the add-on.
#
# The add-on's options live in /data/options.json. We read them with python
# rather than jq - python is already there, jq would be one more package in
# the image.
set -e

OPTS=/data/options.json

MISTER=""
if [ -f "$OPTS" ]; then
    MISTER=$(python3 -c "
import json
try:
    print((json.load(open('$OPTS')).get('mister_ip') or '').strip())
except Exception:
    print('')
")
fi

if [ -n "$MISTER" ]; then
    export MISTER_URL="http://${MISTER}:8182/api/locations"
    echo "[smz3-logic] MiSTer: ${MISTER}"
else
    # Without an address reachd falls back on its local annotations.json.
    # The map works, but new markers do not show until the address is set.
    echo "[smz3-logic] WARNING: no mister_ip set in the add-on's options."
    echo "[smz3-logic] The map markers are then read from the bundled"
    echo "[smz3-logic] fallback file instead of from the MiSTer."
fi

echo "[smz3-logic] Archipelago: ${AP_PATH}"
cd /opt/logic
exec python3 /opt/logic/reachd.py
