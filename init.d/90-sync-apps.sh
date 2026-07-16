#!/usr/bin/env bash
set -euo pipefail

tethys db sync
tethys syncstores all
