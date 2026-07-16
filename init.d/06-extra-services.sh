#!/usr/bin/env bash
set -euo pipefail

GS_SERVICE_NAME="${GS_SERVICE_NAME:-tethys_geoserver}"

if [ -n "${TETHYS_GS_HOST:-}" ]; then
  GS_URL="${TETHYS_GS_USERNAME}:${TETHYS_GS_PASSWORD}@${TETHYS_GS_PROTOCOL}://${TETHYS_GS_HOST}:${TETHYS_GS_PORT}"
  GS_URL_PUB="${TETHYS_GS_PROTOCOL_PUB}://${TETHYS_GS_HOST_PUB}:${TETHYS_GS_PORT_PUB}"
  tethys services create spatial -t GeoServer -n "${GS_SERVICE_NAME}" \
    -c "${GS_URL}" -p "${GS_URL_PUB}" \
    || echo "(service ${GS_SERVICE_NAME} may already exist - continuing)"
fi
