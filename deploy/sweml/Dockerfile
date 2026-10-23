# syntax=docker/dockerfile:1
# Build the SWEML app on the CIROH Tethys base so the portal OIDC login backend,
# the S3 static fix, and the branded login templates ship in the image. Build
# context is the portal repo root, so the app comes from the apps/tethysapp-sweml
# submodule (Aquaveo/tethysapp-sweml) and the deps come from deploy/sweml.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/sweml/requirements.txt ${TETHYS_HOME}/sweml-requirements.txt
COPY apps/tethysapp-sweml ${TETHYS_HOME}/apps/tethysapp-sweml

RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/sweml-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && cd ${TETHYS_HOME}/apps/tethysapp-sweml \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3"

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
