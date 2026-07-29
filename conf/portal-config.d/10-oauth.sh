#!/usr/bin/env bash
set -euo pipefail

# CIROH: inject OAuth secrets (HydroShare + OIDC) from env into OAUTH_CONFIG. Runs in every
# container via portal-config.sh, so both the init/provision path and the web pods pick them up.
if [ -n "${HYDROSHARE_CLIENT_ID:-}" ]; then
  tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_KEY "${HYDROSHARE_CLIENT_ID}"
  tethys settings --set OAUTH_CONFIG.SOCIAL_AUTH_HYDROSHARE_SECRET "${HYDROSHARE_SECRET_ID:?HYDROSHARE_SECRET_ID is required with HYDROSHARE_CLIENT_ID}"
fi
if [ -n "${OIDC_RSA_PRIVATE_KEY:-}" ]; then
  tethys settings --set OAUTH_CONFIG.OAUTH2_PROVIDER.OIDC_RSA_PRIVATE_KEY "${OIDC_RSA_PRIVATE_KEY}"
fi
