# syntax=docker/dockerfile:1
# Build the Snow Inspector app on the CIROH Tethys base so the portal OIDC login
# backend, the S3 static fix, and the branded login templates ship in the image.
# Build context is the portal repo root, so the app comes from the
# apps/snow-inspector submodule (Aquaveo/snow-inspector).
#
# The app's install.yml is broken (it lists a bogus pip dep "see" and omits
# hs_restclient) and its pyproject.toml declares no dependencies, so the runtime
# deps come from deploy/snow-inspector/requirements.txt instead. No GDAL and no
# npm build are needed: the app is server rendered and reads public NASA
# GIBS/Earthdata tiles.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

COPY deploy/snow-inspector/requirements.txt ${TETHYS_HOME}/snow-requirements.txt
COPY apps/snow-inspector ${TETHYS_HOME}/apps/snow-inspector

# Single-app mode serves controllers at root ("/snow_data/", "/pixel-borders/"),
# but the app JS builds those URLs assuming the multi-app "/apps/snow-inspector/"
# layout (window.location.pathname.split('/snow-inspector')), which 404s at "/".
# Rewrite the built JS to root-absolute endpoints, then guard the split is gone.
RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/snow-requirements.txt \
    && cd ${TETHYS_HOME}/apps/snow-inspector \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3" \
    && PKG=/opt/conda/envs/tethys/lib/python3.12/site-packages/tethysapp/snow_inspector \
    && sed -i "s#window\.location\.pathname\.split('/snow-inspector')\[0\] +##g; s#\"/snow-inspector/#\"/#g" "${PKG}"/public/js/*.js \
    && ! grep -rIn "location.pathname.split('/snow-inspector')" "${PKG}/public"

FROM ${UVX_RUNTIME}

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
