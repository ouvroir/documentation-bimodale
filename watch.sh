#!/bin/sh
# Surveille les .md, le template, le filtre et le dossier images/

[ -f bimodale.config.mk ] && . ./bimodale.config.mk
SRC_DIR="${SRC_DIR:-.}"

SENTINEL=".watch_sentinel"
touch "$SENTINEL"

echo "Surveillance active — Ctrl+C pour arrêter"
make

while true; do
    sleep 1
    CHANGED_MD=$(find "$SRC_DIR" -maxdepth 1 -name "*.md" -newer "$SENTINEL")
    CHANGED_TPL=$(find ./template -name "*.html" -newer "$SENTINEL" 2>/dev/null)
    CHANGED_FILTER=$(find ./filters -name "*.lua" -newer "$SENTINEL" 2>/dev/null)
    CHANGED_IMG=$(find "$SRC_DIR/images" -newer "$SENTINEL" 2>/dev/null)
    if [ -n "$CHANGED_MD" ] || [ -n "$CHANGED_TPL" ] || [ -n "$CHANGED_FILTER" ] || [ -n "$CHANGED_IMG" ]; then
        echo "[$(date +%H:%M:%S)] Modification détectée"
        touch "$SENTINEL"
        make
    fi
done
