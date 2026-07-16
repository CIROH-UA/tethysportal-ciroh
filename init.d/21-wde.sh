#!/usr/bin/env bash
set -euo pipefail

tethys link "persistent:${POSTGIS_SERVICE_NAME:-tethys_postgis}" \
  "water_data_explorer:ps_database:catalog_db" \
  || echo "(link may already exist - continuing)"
