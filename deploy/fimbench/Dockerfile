# syntax=docker/dockerfile:1
# Build the FIMbench app on the CIROH Tethys base so the portal OIDC login
# backend, the S3 static fix, and the branded login templates ship in the image.
# Build context is the portal repo root; the app comes from the apps/fimbench
# submodule (Aquaveo/fimbench-gui). React frontend builds with Vite into the
# app's public/ tree, which uv pip install picks up via package-data.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_7b6f2eb3f4ce67d81e1f10fc2ff7fce6fae14257
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm

WORKDIR ${TETHYS_HOME}

COPY apps/fimbench ${TETHYS_HOME}/apps/fimbench

# The app's vite.config hardcodes base '/apps/fimbench-gui/' in production, which
# makes the React Router basename wrong for single-app mode (served at '/') and
# renders a blank page. Override base to '/' via the Vite CLI (npm passes args
# after -- to `vite build`), leaving vite.config.ts untouched.
#
# The React bundle also hardcodes '/static/fimbench_gui/' image paths (logo, docs,
# CSS backgrounds) as app-origin URLs, but static is served from S3 under
# s3Static, so those 404. Rewrite them to the S3 static base in the built output.
ARG STATIC_BASE=https://ciroh-portal-assets.s3.amazonaws.com/static
RUN --mount=type=cache,target=/cache/uv --mount=type=cache,target=/cache/npm \
    cd ${TETHYS_HOME}/apps/fimbench/reactapp && npm install && npm run build -- --base=/ \
    && find ../tethysapp/fimbench_gui/public/frontend -type f \( -name '*.js' -o -name '*.css' \) -print0 \
       | xargs -0 sed -i "s#/static/fimbench_gui/#${STATIC_BASE}/fimbench_gui/#g" \
    && cd ${TETHYS_HOME}/apps/fimbench \
    && uv pip install pandas boto3 \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3"

FROM ${UVX_RUNTIME}

# Re-own the copied env to the runtime's non-root user (1000) during the copy,
# so nothing runs as root and no chmod is needed. tethys-uvx runs rootless.
COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
