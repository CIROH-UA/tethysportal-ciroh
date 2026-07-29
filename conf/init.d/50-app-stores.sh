#!/usr/bin/env bash
set -euo pipefail

# Link CIROH's app persistent stores to the PostGIS service, then sync them. Runs via the base
# provision.sh (init.d loop), AFTER configure-services.sh has created the service and after migrate —
# so `tethys syncstores` has both the service and the schema it needs. The service connects as the
# least-privilege store role (tethys_app); see README §2.5.
SVC="${POSTGIS_SERVICE_NAME:-tethys_postgis}"

tethys link "persistent:${SVC}" "tethysdash:ps_database:primary_db"     || echo "  (tethysdash link may already exist)"
tethys link "persistent:${SVC}" "fimserve_viewer:ps_database:jobs_db"   || echo "  (fimserve_viewer link may already exist)"
tethys syncstores all
