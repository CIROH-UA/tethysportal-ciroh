#!/usr/bin/env bash
set -euo pipefail

if [ "${RUN_STORE_SETUP:-true}" != "true" ]; then
  echo "(RUN_STORE_SETUP=false - store links handled outside the pod, skipping)"
  exit 0
fi

echo "==> link PostGIS service to fimserve_viewer jobs store"
tethys link "persistent:${POSTGIS_SERVICE_NAME}" "fimserve_viewer:ps_database:jobs_db" \
  || echo "    (link may already exist - continuing)"
