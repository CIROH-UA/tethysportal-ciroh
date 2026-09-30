# syntax=docker/dockerfile:1
# Build the Hydro Correlation Tool on the CIROH Tethys base so the portal OIDC
# login backend, the S3 static fix, and the branded login templates ship in the
# image. Build context is the portal repo root, so the app comes from the
# apps/hydro-correlation-tool submodule and the deps come from
# deploy/hydro-correlation-tool.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_9aa1fb30f333da7bead57939b0ac0651b0ea3090
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/hydro-correlation-tool/requirements.txt ${TETHYS_HOME}/hct-requirements.txt
COPY apps/hydro-correlation-tool ${TETHYS_HOME}/apps/hydro-correlation-tool

RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/hct-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && cd ${TETHYS_HOME}/apps/hydro-correlation-tool \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3"

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
