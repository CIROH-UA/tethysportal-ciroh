#!/usr/bin/env bash
set -euo pipefail

THREDDS_SERVICE_NAME="${THREDDS_SERVICE_NAME:-tethys_thredds}"
GS_SERVICE_NAME="${GS_SERVICE_NAME:-tethys_geoserver}"

if [ -n "${THREDDS_TDS_PRIVATE_HOST:-}" ]; then
  THREDDS_PRIVATE_URL="${THREDDS_TDS_USERNAME}:${THREDDS_TDS_PASSWORD}@${THREDDS_TDS_PRIVATE_PROTOCOL}://${THREDDS_TDS_PRIVATE_HOST}:${THREDDS_TDS_PRIVATE_PORT}${THREDDS_TDS_CATALOG}"
  THREDDS_PUBLIC_URL="${THREDDS_TDS_PUBLIC_PROTOCOL}://${THREDDS_TDS_PUBLIC_HOST}:${THREDDS_TDS_PUBLIC_PORT}${THREDDS_TDS_CATALOG}"
  tethys services create spatial -t THREDDS -n "${THREDDS_SERVICE_NAME}" \
    -c "${THREDDS_PRIVATE_URL}" -p "${THREDDS_PUBLIC_URL}" \
    || echo "(service ${THREDDS_SERVICE_NAME} may already exist - continuing)"
fi

if [ -n "${TETHYS_GS_HOST:-}" ]; then
  GS_URL="${TETHYS_GS_USERNAME}:${TETHYS_GS_PASSWORD}@${TETHYS_GS_PROTOCOL}://${TETHYS_GS_HOST}:${TETHYS_GS_PORT}"
  GS_URL_PUB="${TETHYS_GS_PROTOCOL_PUB}://${TETHYS_GS_HOST_PUB}:${TETHYS_GS_PORT_PUB}"
  tethys services create spatial -t GeoServer -n "${GS_SERVICE_NAME}" \
    -c "${GS_URL}" -p "${GS_URL_PUB}" \
    || echo "(service ${GS_SERVICE_NAME} may already exist - continuing)"
fi
