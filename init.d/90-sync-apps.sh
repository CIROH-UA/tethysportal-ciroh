#!/usr/bin/env bash
set -euo pipefail

if [ "${RUN_STORE_SETUP:-true}" != "true" ]; then
  echo "(RUN_STORE_SETUP=false - store sync handled outside the pod, skipping)"
  exit 0
fi

tethys db sync
tethys syncstores all
