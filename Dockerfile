# syntax=docker/dockerfile:1
ARG UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder-a3148d5@sha256:09f38d1f969a0eec84f78a4f3d1a0748c1595654ce3c98e56ec1af91036d6202
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base-a3148d5@sha256:8fa7c6d9bf2ad7b70d821734f6227e01ecd3d0585c5695041e6c8d6546354f31

FROM ${UVX_BUILDER} AS builder

# Point uv + npm at fixed cache dirs backed by BuildKit cache mounts.
ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm

WORKDIR ${TETHYS_HOME}

COPY requirements/piprequirements.txt ./piprequirements.txt
COPY requirements/overrides.txt ${TETHYS_HOME}/overrides.txt
RUN --mount=type=cache,target=/cache/uv uv pip install -r piprequirements.txt --overrides ${TETHYS_HOME}/overrides.txt

# Dashboard plugins used by the CIROH portal landing (ciroh_plugins) plus the
# TethysDash plugin set. Kept in the hub.
RUN --mount=type=cache,target=/cache/uv uv pip install --overrides ${TETHYS_HOME}/overrides.txt \
    git+https://github.com/FIRO-Tethys/ciroh_plugins.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usace.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cnrfc.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cw3e.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin-great_lakes_viewer.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usgs_water_services.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_geoglows.git \
    git+https://github.com/FIRO-Tethys/RFC-Plugins.git
COPY extensions ${TETHYS_HOME}/extensions
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && uv pip install .

# The viewer/data apps (sweml, hydrocompute, snow-inspector, tethysdash, cses,
# fimbench, fimserve_viewer, usgs-mrms, hydro-correlation-tool, nrds, ngiab) now
# run as standalone deployments (deploy/<app>/ overlays + their own images), so
# they are intentionally NOT installed here. This keeps the portal a lean hub: the
# OIDC provider, the CIROH theme, and the app library of ProxyApp cards that link
# out to each app's subdomain.

RUN chmod -R a+rX /opt/python /opt/conda \
  && chmod -R a+rwX ${VIRTUAL_ENV}/lib/python3.12/site-packages/ciroh_plugins

FROM ${UVX_RUNTIME}

ENV POSTGIS_SERVICE_NAME="tethys_postgis"

COPY --from=builder /opt/python /opt/python
COPY --from=builder /opt/conda /opt/conda
COPY --chown=1000:1000 conf/portal_config.yml /config/portal_config.yml
# Portal-owned S3 storage backend (base no longer ships it); on PYTHONPATH=/opt/portal.
COPY conf/portal_storage.py /opt/portal/portal_storage.py
# Portal-owned config hook: OAuth secrets from env (base portal-config.sh runs it).
COPY --chmod=0755 conf/portal-config.d/ /opt/portal/portal-config.d/
# Portal-owned provision hook: link app stores + syncstores (base provision.sh runs it).
COPY --chmod=0755 conf/init.d/ /opt/portal/init.d/

# NOTE: the DB bootstrap + portal seed are DEV-ONLY tools and live in dev/ — they are
# deliberately NOT baked into this image. The docker-compose dev stack mounts dev/ and
# runs them; prod provisioning is migrate + syncstores (chart hooks) + DBA SQL on RDS
# (README §2.5). CMD (serve.sh) is inherited from base.
