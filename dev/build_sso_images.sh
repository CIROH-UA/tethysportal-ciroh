#!/usr/bin/env bash
# Build and push personal (gioelkin/) images for the portal SSO rollout, ahead of CI:
#   1. a CIROH base per pinned base an app uses, rebuilt FROM that pinned base so only
#      deploy/oidc (login template + logout middleware) changes, tagged
#      gioelkin/ciroh-tethys:sso-<first 8 of the pinned sha>
#   2. each app from deploy/<app>/Dockerfile on its matching new base, tagged
#      gioelkin/tethysapp-<app>:<TAG>, and points deploy/<app>/values-prod.yaml at it.
#
# Run from the portal repo root with the app submodules checked out at the commits
# you want live (git submodule update --init <path>):
#   dev/build_sso_images.sh <tag> <app> [<app> ...]
#   dev/build_sso_images.sh sso-e810e0c cses nrds sweml
set -euo pipefail

TAG=${1:?usage: $0 <tag> <app> [<app> ...]}
shift
[ $# -gt 0 ] || { echo "name at least one app (deploy/<app>)"; exit 1; }
REG=${REG:-gioelkin}

for app in "$@"; do
  dockerfile=deploy/$app/Dockerfile
  values=deploy/$app/values-prod.yaml
  [ -f "$dockerfile" ] || { echo "no $dockerfile"; exit 1; }

  # The pinned base this app builds on today, and its SSO rebuild.
  old_base=$(sed -n 's/^ARG UVX_BUILDER=//p' "$dockerfile")
  pin=${old_base##*builder_}
  new_base=$REG/ciroh-tethys:sso-${pin:0:8}
  if ! docker image inspect "$new_base" >/dev/null 2>&1; then
    echo "== base $new_base (from $old_base)"
    docker build -f deploy/ciroh-tethys/Dockerfile \
      --build-arg TETHYS_UVX_BUILDER="$old_base" -t "$new_base" deploy
    docker run --rm --entrypoint /opt/conda/envs/tethys/bin/python "$new_base" \
      -c "import ciroh_portal_oidc as m; m.PortalLogoutMiddleware"
  fi

  # Repository from the overlay (e.g. awiciroh/tethysapp-cses -> gioelkin/tethysapp-cses).
  repo=$(sed -n '0,/^  repository:/s/^  repository: *//p' "$values" | tr -d "'\"")
  image=$REG/${repo#*/}:$TAG
  echo "== $app -> $image"
  docker build -f "$dockerfile" --build-arg UVX_BUILDER="$new_base" -t "$image" .
  docker run --rm --entrypoint /opt/conda/envs/tethys/bin/python "$image" \
    -c "import ciroh_portal_oidc as m; m.PortalLogoutMiddleware"
  docker push "$image"

  # Point the overlay at the new image (top-level image: block only).
  sed -i "0,/^  repository:/s|^  repository:.*|  repository: $REG/${repo#*/}|; 0,/^  tag:/s|^  tag:.*|  tag: $TAG|" "$values"
  grep -n -A2 '^image:' "$values"
done
