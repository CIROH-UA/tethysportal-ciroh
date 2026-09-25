# syntax=docker/dockerfile:1
# Build the TethysDash app on the CIROH Tethys base so the portal OIDC login
# backend, the leading slash S3 static fix, and the branded login templates ship
# in the image. Build context is the portal repo root; the app comes from the
# apps/tethysapp-tethys_dash submodule (tethysplatform/tethysapp-tethys_dash).
#
# TethysDash is a React/webpack SPA. dotenv-webpack bakes URLs into the bundle at
# BUILD time by reading reactapp/config/production.env (which the app gitignores),
# so deploy/tethysdash/production.env is copied in before `npm run build` to point
# the SPA at the single-app root ("/") and at the per-subdomain WebSocket.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_9aa1fb30f333da7bead57939b0ac0651b0ea3090
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm
# The app submodule ships without usable git metadata in the build context, so
# pin the version for setuptools_scm instead of computing it from git.
ENV SETUPTOOLS_SCM_PRETEND_VERSION_FOR_TETHYSDASH=0.19.12

WORKDIR ${TETHYS_HOME}

COPY apps/tethysapp-tethys_dash ${TETHYS_HOME}/apps/tethysapp-tethys_dash
COPY deploy/tethysdash/production.env ${TETHYS_HOME}/apps/tethysapp-tethys_dash/reactapp/config/production.env

# The production build bakes publicPath "/static/tethysdash/frontend/" into the
# webpack runtime, but static is served from S3 under s3Static, so same-origin
# "/static/..." chunk and asset URLs 404. Rewrite them to the S3 static base in
# the built output, the same way the FIMbench image handles its React bundle.
ARG STATIC_BASE=https://ciroh-portal-assets.s3.amazonaws.com/static
RUN --mount=type=cache,target=/cache/uv --mount=type=cache,target=/cache/npm \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_dash \
    && npm install \
    && npm run build \
    && find tethysapp/tethysdash/public/frontend -type f \( -name '*.js' -o -name '*.css' \) -print0 \
       | xargs -0 -r sed -i "s#/static/tethysdash/#${STATIC_BASE}/tethysdash/#g" \
    && uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3, channels_redis, django_redis, geoalchemy2, alembic, psycopg2, intake"

FROM ${UVX_RUNTIME}

# Re-own the copied env to the runtime's non-root user (1000) during the copy,
# so nothing runs as root and no chmod is needed. tethys-uvx runs rootless.
COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
