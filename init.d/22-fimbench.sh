#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FIMBENCH_S3_BUCKET_URL:-}" ]; then
  echo "(FIMbench env not set - skipping)"
  exit 0
fi

tethys app_settings set fimbench_gui s3_allowed_host "${FIMBENCH_S3_ALLOWED_HOST}"
tethys app_settings set fimbench_gui s3_bucket_url "${FIMBENCH_S3_BUCKET_URL}"
tethys app_settings set fimbench_gui s3_catalog_key "${FIMBENCH_S3_CATALOG_KEY}"
tethys app_settings set fimbench_gui s3_viz_tiles "${FIMBENCH_S3_VIZ_TILES}"
