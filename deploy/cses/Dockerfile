# syntax=docker/dockerfile:1
# Build the CSES app on the CIROH Tethys base so the portal OIDC login backend,
# the S3 static fix, and the branded login templates ship in the image. Build
# context is the portal repo root, so the app comes from the apps/Tethys-CSES
# submodule (Aquaveo/Tethys-CSES) and the deps come from deploy/cses.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_7f91b35f42883e079a11e9d94429201d51bc8acd
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

# The app's package-data globs are lowercase, so uppercase-extension statics
# (CSESoverviewImage.JPG) are dropped on install and 403 from S3. The cp below
# syncs the full public tree into the installed package so collectstatic sees it.

RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/cses-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && cd ${TETHYS_HOME}/apps/Tethys-CSES \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages" \
    && cp -a tethysapp/community_streamflow_evaluation_system/public/. \
       /opt/conda/envs/tethys/lib/python3.12/site-packages/tethysapp/community_streamflow_evaluation_system/public/ \
    && test -f /opt/conda/envs/tethys/lib/python3.12/site-packages/tethysapp/community_streamflow_evaluation_system/public/images/CSESoverviewImage.JPG

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
