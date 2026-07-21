#!/usr/bin/env bash
set -euo pipefail

failed=()
for hook in /opt/portal/init.d/*.sh; do
  echo "==> init hook ${hook##*/}"
  bash "$hook" || { echo "    (hook ${hook##*/} FAILED - continuing with remaining hooks)"; failed+=("${hook##*/}"); }
done

if [ "${#failed[@]}" -gt 0 ]; then
  echo "Init hooks FAILED: ${failed[*]}"
  exit 1
fi
echo "Init hooks complete"
