#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GGST_CS_THREDDS_DIRECTORY:-}" ]; then
  echo "(GGST env not set - skipping)"
  exit 0
fi

tethys app_settings set ggst grace_thredds_directory "${GGST_CS_THREDDS_DIRECTORY}"
tethys app_settings set ggst grace_thredds_catalog "${GGST_CS_THREDDS_CATALOG}"
tethys app_settings set ggst global_output_directory "${GGST_CS_GLOBAL_OUTPUT_DIRECTORY}"
tethys app_settings set ggst earthdata_username "${GGST_CS_EARTHDATA_USERNAME}"
tethys app_settings set ggst earthdata_pass "${GGST_CS_EARTHDATA_PASS}"
tethys app_settings set ggst conda_python_path "${GGST_CS_CONDA_PYTHON_PATH}"
