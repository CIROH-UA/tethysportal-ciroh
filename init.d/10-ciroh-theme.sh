#!/usr/bin/env bash
set -euo pipefail

tethys site --site-title "CIROH Portal" \
  --apps-library-title "Tools" \
  --primary-color "#255f9c" \
  --secondary-color "#75acc4" \
  --background-color "#ffffff" \
  --brand-image "/ciroh_theme/images/CIROHLogo.png" \
  --favicon "/ciroh_theme/images/favicon.ico" \
  --hero-text "${HERO_TEXT:-}" \
  --blurb-text "${BLURB_TEXT:-}" \
  --feature-1-heading "${FEATURE_1_HEADING:-}" \
  --feature-1-body "${FEATURE_1_BODY:-}" \
  --feature-1-image "/ciroh_theme/images/feature_1.png" \
  --feature-2-heading "${FEATURE_2_HEADING:-}" \
  --feature-2-body "${FEATURE_2_BODY:-}" \
  --feature-2-image "/ciroh_theme/images/feature_2.png" \
  --feature-3-heading "${FEATURE_3_HEADING:-}" \
  --feature-3-body "${FEATURE_3_BODY:-}" \
  --feature-3-image "/ciroh_theme/images/feature_3.png" \
  --copyright "Copyright © 2025 CIROH"
