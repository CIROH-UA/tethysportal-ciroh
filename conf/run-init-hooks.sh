#!/usr/bin/env bash
set -euo pipefail

for hook in /opt/portal/init.d/*.sh; do
  echo "==> init hook ${hook##*/}"
  bash "$hook" || echo "    (hook ${hook##*/} failed - continuing)"
done
echo "Init hooks complete"
