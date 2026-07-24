#!/usr/bin/env bash
set -euo pipefail

# portal-seed.sh — one-time, idempotent configuration of a FRESH portal database.
#
# Consolidates what the removed init.d hooks did (recovered from git history):
#   - PostGIS persistent-store service + app store links + syncstores
#   - branding / site settings (was 10-ciroh-theme.sh)
#   - proxy apps (was 30-proxy-apps.sh)
#   - optional app settings: fimbench S3, CSES key (was 22-fimbench / 23-cses)
#
# Run it EXPLICITLY against a fresh DB; it is NOT part of the deploy loop and is
# never run automatically in production (prod's DB already carries this state).
#
#   docker compose -f docker-compose.dev.yml exec web portal-seed.sh
#   k3d/k8s:  kubectl exec deploy/<release> -- portal-seed.sh
#
# Idempotent: safe to re-run. Optional app settings are applied only when their
# env vars are set (mirroring the original hooks). Values default to the CIROH
# production set; override via env (e.g. PROXY_APP_ORIGIN for a local back-URL).

POSTGIS_SERVICE_NAME="${POSTGIS_SERVICE_NAME:-tethys_postgis}"
# Persistent-store connection: prefer TETHYS_PS_CONNECTION, else build it from
# the SUPERUSER env (user:pass@host:port). Must be the superuser, not the app
# role: the store service needs CREATEDB to make each app's store database, and
# Tethys' store handlers connect with no dbname (libpq then defaults it to the
# username) — so the username must match the landing database that
# bootstrap-database.sh creates (named after the admin role).
PS_CONN="${TETHYS_PS_CONNECTION:-${TETHYS_DB_SUPERUSER}:${TETHYS_DB_SUPERUSER_PASS}@${TETHYS_DB_HOST}:${TETHYS_DB_PORT}}"
PROXY_APP_ORIGIN="${PROXY_APP_ORIGIN:-https://tethys.ciroh.org/t}"

echo "==> [1/6] PostGIS persistent-store service '${POSTGIS_SERVICE_NAME}'"
tethys services create persistent -n "${POSTGIS_SERVICE_NAME}" -c "${PS_CONN}" \
  || echo "    (service may already exist — continuing)"

echo "==> [2/6] link app persistent stores"
tethys link "persistent:${POSTGIS_SERVICE_NAME}" "tethysdash:ps_database:primary_db" \
  || echo "    (tethysdash link may already exist)"
tethys link "persistent:${POSTGIS_SERVICE_NAME}" "fimserve_viewer:ps_database:jobs_db" \
  || echo "    (fimserve_viewer link may already exist)"

echo "==> [3/6] sync stores"
tethys db sync
tethys syncstores all

echo "==> [4/6] branding / site settings"
tethys site --site-title "CIROH Portal" \
  --apps-library-title "Tools" \
  --primary-color "#255f9c" \
  --secondary-color "#75acc4" \
  --background-color "#ffffff" \
  --brand-image "/ciroh_theme/images/CIROHLogo.png" \
  --favicon "/ciroh_theme/images/favicon.ico" \
  --copyright "Copyright © 2025 CIROH"

echo "==> [5/6] proxy apps"
tethys proxyapp add "OWP NWM Map Viewer" "https://water.noaa.gov/map" "Proxy app for Office in Water Prediction" "/static/ciroh_theme/images/owp.png" "NOAA" True True "${PROXY_APP_ORIGIN}" True True \
  || echo "    (OWP proxy app may already exist)"
tethys proxyapp add "CIROH JupyterHub" "https://jupyterhub.cuahsi.org/hub/login" "Proxy app for the CIROH JupyterHub" "/static/ciroh_theme/images/jupyterhub.png" "CUAHSI" True True "${PROXY_APP_ORIGIN}" True True \
  || echo "    (JupyterHub proxy app may already exist)"
tethys proxyapp add "HydroShare" "https://water.noaa.gov/map" "Proxy app for the Hydroshare app" "/static/ciroh_theme/images/HydroShare.png" "CUAHSI" True True "${PROXY_APP_ORIGIN}" True True \
  || echo "    (HydroShare proxy app may already exist)"

echo "==> [6/6] optional app settings"
if [ -n "${FIMBENCH_S3_BUCKET_URL:-}" ]; then
  echo "    fimbench_gui S3 settings"
  tethys app_settings set fimbench_gui s3_allowed_host "${FIMBENCH_S3_ALLOWED_HOST}"
  tethys app_settings set fimbench_gui s3_bucket_url "${FIMBENCH_S3_BUCKET_URL}"
  tethys app_settings set fimbench_gui s3_catalog_key "${FIMBENCH_S3_CATALOG_KEY}"
  tethys app_settings set fimbench_gui s3_viz_tiles "${FIMBENCH_S3_VIZ_TILES}"
else
  echo "    (FIMBENCH_S3_* not set — skipping fimbench settings)"
fi
if [ -n "${CSES_ACCESS_KEY_ID:-}" ]; then
  echo "    community_streamflow_evaluation_system Access_key_ID"
  tethys app_settings set community_streamflow_evaluation_system Access_key_ID "${CSES_ACCESS_KEY_ID}"
else
  echo "    (CSES_ACCESS_KEY_ID not set — skipping CSES setting)"
fi

echo "portal-seed complete."
