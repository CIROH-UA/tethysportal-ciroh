# syntax=docker/dockerfile:1
# FIMserve Viewer as a standalone app image on the CIROH Tethys base, so the
# portal OIDC login backend and S3 static storage ship with it. Build context
# is the portal repo root; the app comes from the apps/fimserv-viewer
# submodule (Aquaveo/fimserv-viewer):
#   docker build -f deploy/fimserve/Dockerfile .
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

# The chart's Dask workers preload tethysapp.fimserve_viewer.dask_worker; set to
# false only for app source without the Dask offload (and dask.enabled=false).
ARG DASK_OFFLOAD=true

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/fimserve/requirements.txt ${TETHYS_HOME}/requirements.txt
COPY apps/fimserv-viewer ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer

RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer \
    && uv pip install . --overrides ${TETHYS_HOME}/requirements.txt \
    && uv pip uninstall nodejs-bin \
    && uv pip install --overrides ${TETHYS_HOME}/requirements.txt "gdal==$(gdal-config --version)" \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3, dask.distributed" \
    && /opt/conda/envs/tethys/bin/python -c "import fimserve.datadownload, fimserve.runFIM" \
    && if [ "${DASK_OFFLOAD}" = "true" ]; then \
         /opt/conda/envs/tethys/bin/python -c "import tethysapp.fimserve_viewer.dask_worker"; \
       fi

# Tests against the built env (not shipped):
#   docker build ... --target test -t fimserve:test . && docker run --rm fimserve:test
FROM builder AS test
WORKDIR ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer
CMD ["bash", "-c", "set -e; if [ -d tests ]; then python -m unittest discover -s tests; fi; tethys db migrate >/dev/null && tethys manage test tethysapp/fimserve_viewer/tests"]

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin git \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
