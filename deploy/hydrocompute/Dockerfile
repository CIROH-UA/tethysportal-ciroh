# syntax=docker/dockerfile:1
# Build the HydroCompute app on the CIROH Tethys base so the portal OIDC login
# backend, the S3 static fix, and the branded login templates ship in the image.
# Build context is the portal repo root, so the app comes from the
# apps/tethysapp-hydrocompute submodule (Aquaveo/tethysapp-hydrocompute). The app
# is server rendered with no GDAL, no npm, and no extra runtime deps.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_9aa1fb30f333da7bead57939b0ac0651b0ea3090
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

COPY apps/tethysapp-hydrocompute ${TETHYS_HOME}/apps/tethysapp-hydrocompute

RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3"

FROM ${UVX_RUNTIME}

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
