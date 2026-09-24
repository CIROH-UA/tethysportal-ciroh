# syntax=docker/dockerfile:1
# Build the CSES app on the CIROH Tethys base so the portal OIDC login backend,
# the S3 static fix, and the branded login templates ship in the image. Build
# context is the portal repo root, so the app comes from the apps/Tethys-CSES
# submodule (Aquaveo/Tethys-CSES) and the deps come from deploy/cses.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_2f82ca658945cb6f69818b3d98ed820b646cef99
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/cses/requirements.txt ${TETHYS_HOME}/cses-requirements.txt
COPY apps/Tethys-CSES ${TETHYS_HOME}/apps/Tethys-CSES

RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/cses-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && cd ${TETHYS_HOME}/apps/Tethys-CSES \
    && uv pip install .

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/python /opt/python
COPY --from=builder /opt/conda /opt/conda
RUN chmod -R a+rwX /opt/conda/envs/tethys/lib/python3.12/site-packages/tethysapp

USER 1000:1000
