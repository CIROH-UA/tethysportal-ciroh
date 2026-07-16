#!/usr/bin/env bash
set -euo pipefail

if [ -z "${CSES_ACCESS_KEY_ID:-}" ]; then
  echo "(CSES env not set - skipping)"
  exit 0
fi

tethys app_settings set community_streamflow_evaluation_system Access_key_ID "${CSES_ACCESS_KEY_ID}"
