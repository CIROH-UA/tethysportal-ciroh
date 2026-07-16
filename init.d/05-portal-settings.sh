#!/usr/bin/env bash
set -euo pipefail

if [ -n "${FILE_UPLOAD_MAX_MEMORY_SIZE:-}" ]; then
  tethys settings --set FILE_UPLOAD_MAX_MEMORY_SIZE "${FILE_UPLOAD_MAX_MEMORY_SIZE}"
  tethys settings --set DATA_UPLOAD_MAX_MEMORY_SIZE "${FILE_UPLOAD_MAX_MEMORY_SIZE}"
  tethys settings --set DATA_UPLOAD_MAX_NUMBER_FIELDS "${FILE_UPLOAD_MAX_MEMORY_SIZE}"
fi

if [ -n "${CSRF_TRUSTED_ORIGINS:-}" ]; then
  tethys settings --set CSRF_TRUSTED_ORIGINS "${CSRF_TRUSTED_ORIGINS}"
fi

if [ -n "${PREFIX_URL:-}" ]; then
  tethys settings --set PREFIX_URL "${PREFIX_URL}"
fi

if [ -n "${ENABLE_OPEN_PORTAL:-}" ]; then
  tethys settings --set TETHYS_PORTAL_CONFIG.ENABLE_OPEN_PORTAL "${ENABLE_OPEN_PORTAL}"
fi
