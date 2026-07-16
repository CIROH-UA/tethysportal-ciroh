#!/usr/bin/env bash
set -euo pipefail

FLAG="${TETHYS_PERSIST}/init_proxy_apps_setup_complete"
if [ -f "${FLAG}" ]; then
  exit 0
fi

tethys proxyapp add "OWP NWM Map Viewer" "https://water.noaa.gov/map" "Proxy app for Office in Water Prediction" "/static/ciroh_theme/images/owp.png" "NOAA" True True "https://tethys.ciroh.org/t" True True
tethys proxyapp add "CIROH JupyterHub" "https://jupyterhub.cuahsi.org/hub/login" "Proxy app for the CIROH JupyterHub" "/static/ciroh_theme/images/jupyterhub.png" "CUAHSI" True True "https://tethys.ciroh.org/t" True True
tethys proxyapp add "HydroShare" "https://water.noaa.gov/map" "Proxy app for the Hydroshare app" "/static/ciroh_theme/images/HydroShare.png" "CUAHSI" True True "https://tethys.ciroh.org/t" True True

touch "${FLAG}"
