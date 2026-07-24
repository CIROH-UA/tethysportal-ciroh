#!/usr/bin/env bash
set -euo pipefail

# Single-container setups (docker-compose) have no separate init Job, so run the
# full portal init (migrate + config + services + bootstrap) here before serving.
# Opt-in via RUN_INIT_ON_START=true. k8s/k3d leaves this false: its init Job
# (and provision hook) already do setup, so web pods must not re-run it.
if [ "${RUN_INIT_ON_START:-false}" = "true" ]; then
  echo "RUN_INIT_ON_START=true -> running init-tethys.sh (migrate/bootstrap) before serving"
  /usr/local/bin/init-tethys.sh
fi

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

# Dev mode: run Django's development server instead of uvicorn. With DEBUG on,
# runserver serves /static/ directly from each app's static dir (via the
# staticfiles finders), so a local portal needs no S3/CDN and no collectstatic.
# Enabled by TETHYS_DEV_SERVER=true (docker-compose env or the k3d dev values).
# Never enable in production: runserver is single-threaded and DEBUG leaks info.
if [ "${TETHYS_DEV_SERVER:-false}" = "true" ]; then
  echo "Starting in DEV mode: DEBUG=True + runserver (static served locally, no CDN)"
  tethys settings --set DEBUG True
  # Use the `start` command (not `runserver -p ...`): only `start` forwards the
  # port to manage.py runserver, and passing HOST:PORT binds all interfaces so
  # the dev server is reachable from outside the container. Plain
  # `tethys manage runserver -p ...` drops the port and binds 127.0.0.1 only.
  exec tethys manage -p "${HOST}:${PORT}" start
fi

exec uvicorn "$APP" --host "$HOST" --port "$PORT" --workers "$WORKERS" \
  --forwarded-allow-ips "$FWD" --proxy-headers
