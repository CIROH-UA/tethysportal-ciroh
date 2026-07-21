#!/usr/bin/env bash
set -euo pipefail

echo "==> link PostGIS service to fimserve_viewer jobs store"
tethys link "persistent:${POSTGIS_SERVICE_NAME}" "fimserve_viewer:ps_database:jobs_db" \
  || echo "    (link may already exist - continuing)"
