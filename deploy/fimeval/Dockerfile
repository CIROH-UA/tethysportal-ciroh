# syntax=docker/dockerfile:1
# Build from the portal repo with the app source as a named context:
#   docker build -f deploy/fimeval/Dockerfile \
#     --build-context app=<path to tethysapp-fimeval-gui> deploy/fimeval
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base-a3148d5

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ${TETHYS_HOME}/requirements.txt
COPY --from=app . ${TETHYS_HOME}/apps/tethysapp-fimeval-gui

# Standalone single-app portal serves the SPA at the site root.
RUN --mount=type=cache,target=/cache/uv --mount=type=cache,target=/cache/npm \
    cd ${TETHYS_HOME}/apps/tethysapp-fimeval-gui/reactapp && npm ci && \
    VITE_BASE_URL=/ npm run build && \
    cd ${TETHYS_HOME}/apps/tethysapp-fimeval-gui && \
    uv pip install . --overrides ${TETHYS_HOME}/requirements.txt && \
    uv pip install --overrides ${TETHYS_HOME}/requirements.txt "gdal==$(gdal-config --version)"

# Backend tests against the built env (not shipped):
#   docker build ... --target test -t fimeval:test deploy/fimeval && docker run --rm fimeval:test
FROM builder AS test
RUN --mount=type=cache,target=/cache/uv uv pip install "moto[s3]>=5"
WORKDIR ${TETHYS_HOME}/apps/tethysapp-fimeval-gui
CMD ["bash", "-c", "tethys db migrate >/dev/null && tethys manage test tethysapp/fimeval_gui/tests"]

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
