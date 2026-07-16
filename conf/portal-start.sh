#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/portal-config.sh

if [ -n "${HYDROSHARE_CLIENT_ID:-}" ]; then
  tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_KEY "${HYDROSHARE_CLIENT_ID}"
  tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_SECRET "${HYDROSHARE_SECRET_ID:?HYDROSHARE_SECRET_ID is required with HYDROSHARE_CLIENT_ID}"
fi
if [ -n "${OIDC_RSA_PRIVATE_KEY:-}" ]; then
  tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_RSA_PRIVATE_KEY "${OIDC_RSA_PRIVATE_KEY}"
fi

export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-tethys_portal.settings}"
APP="tethys_portal.asgi:application"
HOST="0.0.0.0"
PORT="${PORT:-${TETHYS_PORT:-8000}}"
WORKERS="${ASGI_PROCESSES:-1}"
FWD="${FORWARDED_ALLOW_IPS:-*}"

exec uvicorn "$APP" --host "$HOST" --port "$PORT" --workers "$WORKERS" \
  --forwarded-allow-ips "$FWD" --proxy-headers
