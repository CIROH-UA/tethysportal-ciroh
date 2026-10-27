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
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm

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

# TethysDash discovers visualizations through installed plugin packages (intake
# entry points), so the dashboards the monolithic portal shipped only render when
# these same plugins are baked into the image.
# ciroh_plugins leaves pygeohydro/pynhd unpinned; without the floor, a newer pynhd
# makes uv fall back to pygeohydro 0.14, which breaks on the current async-retriever.
# The geoglows and usace plugins import pytz without declaring it, and pandas 3 no
# longer pulls it in. The check after the install fails the build when any plugin
# module can't import a dependency, instead of 500ing at runtime.
RUN --mount=type=cache,target=/cache/uv \
    uv pip install \
        "pygeohydro>=0.19" \
        pytz \
        git+https://github.com/FIRO-Tethys/ciroh_plugins.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin_usace.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin_cnrfc.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin_cw3e.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin-great_lakes_viewer.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin_usgs_water_services.git \
        git+https://github.com/FIRO-Tethys/tethysdash_plugin_geoglows.git \
        git+https://github.com/FIRO-Tethys/RFC-Plugins.git \
    && /opt/conda/envs/tethys/bin/python -c "import ciroh_plugins" \
    && /opt/conda/envs/tethys/bin/python -c "$(printf '%s\n' \
         'import importlib, importlib.metadata as m, sys' \
         'mods = sorted({e.value.split(":")[0] for e in m.entry_points(group="intake.drivers")})' \
         'bad = []' \
         'for mod in mods:' \
         '    try: importlib.import_module(mod)' \
         '    except ImportError as ex: bad.append(f"{mod}: {ex}")' \
         '    except Exception: pass  # some plugins fetch data on import; only missing deps fail the build' \
         'print(len(mods), "plugin modules,", len(bad), "missing dependencies")' \
         'print(*bad, sep="\n")' \
         'sys.exit(1 if bad else 0)')"

FROM ${UVX_RUNTIME}

# Re-own the copied env to the runtime's non-root user (1000) during the copy,
# so nothing runs as root and no chmod is needed. tethys-uvx runs rootless.
COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
