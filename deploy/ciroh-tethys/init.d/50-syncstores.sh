#!/usr/bin/env bash
set -euo pipefail

# Sync the app's persistent stores on every provision, so a store initializer's
# schema migrations (e.g. TethysDash's Alembic revisions) run on upgrade. The base
# provision.sh runs hooks from /opt/portal/init.d after migrate; app images copy
# /opt/portal from this base.
#
# `tethys syncstores` exits 0 even when an initializer fails, so read its output:
# a store with no service linked is skipped, any other traceback fails provision.
echo "Syncing persistent stores"
out=$(tethys syncstores all 2>&1) || { echo "$out"; exit 1; }
echo "$out"
errors=$(grep -E '^[A-Za-z_.]+(Error|Exception|NotAssigned)\b' <<<"$out" | grep -v 'TethysAppSettingNotAssigned' || true)
if [ -n "$errors" ]; then
  echo "FATAL: syncstores failed:" >&2
  echo "$errors" >&2
  exit 1
fi
