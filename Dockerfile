# syntax=docker/dockerfile:1
ARG UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder-a3148d5@sha256:09f38d1f969a0eec84f78a4f3d1a0748c1595654ce3c98e56ec1af91036d6202
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base-a3148d5@sha256:8fa7c6d9bf2ad7b70d821734f6227e01ecd3d0585c5695041e6c8d6546354f31

FROM ${UVX_BUILDER} AS builder

ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysapp-tethys_dash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"

# Point uv + npm at fixed cache dirs that are backed by BuildKit cache mounts
# on the RUNs below, so downloaded wheels/tarballs (incl. the ~434 MB pyspark)
# persist across builds instead of being re-fetched every time.
ENV UV_CACHE_DIR=/cache/uv
ENV npm_config_cache=/cache/npm

WORKDIR ${TETHYS_HOME}

COPY requirements/piprequirements.txt ./piprequirements.txt
RUN --mount=type=cache,target=/cache/uv uv pip install -r piprequirements.txt

RUN --mount=type=cache,target=/cache/uv uv pip install \
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

COPY apps/tethysapp-sweml ${TETHYS_HOME}/apps/tethysapp-sweml
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/tethysapp-sweml && uv pip install .

COPY apps/tethysapp-hydrocompute ${TETHYS_HOME}/apps/tethysapp-hydrocompute
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute && uv pip install .

COPY apps/snow-inspector ${TETHYS_HOME}/apps/snow-inspector
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/snow-inspector && uv pip install .

COPY apps/tethysapp-tethys_dash ${TETHYS_HOME}/apps/tethysapp-tethys_dash
RUN --mount=type=cache,target=/cache/uv --mount=type=cache,target=/cache/npm \
    mv ${DEV_REACT_CONFIG} ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_DEBUG_MODE.*#TETHYS_DEBUG_MODE = ${TETHYS_DEBUG_MODE}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_LOADER_DELAY.*#TETHYS_LOADER_DELAY = ${TETHYS_LOADER_DELAY}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_PORTAL_HOST.*#TETHYS_PORTAL_HOST = ${TETHYS_PORTAL_HOST}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_APP_ROOT_URL.*#TETHYS_APP_ROOT_URL = ${TETHYS_APP_ROOT_URL}#g" ${PROD_REACT_CONFIG} && \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_dash && npm install && npm run build && uv pip install .

COPY apps/Tethys-CSES ${TETHYS_HOME}/apps/Tethys-CSES
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/Tethys-CSES && uv pip install .

COPY apps/fimbench ${TETHYS_HOME}/apps/fimbench
RUN --mount=type=cache,target=/cache/uv --mount=type=cache,target=/cache/npm \
    cd ${TETHYS_HOME}/apps/fimbench/reactapp && npm install && npm run build && \
    cd ${TETHYS_HOME}/apps/fimbench && uv pip install .

COPY apps/tethysapp-fimserve_viewer ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer
COPY requirements/overrides.txt ${TETHYS_HOME}/overrides.txt
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer && uv pip install . --overrides ${TETHYS_HOME}/overrides.txt && \
    uv pip uninstall nodejs-bin

# USGS-MRMS: runtime lib (EWS path only -- Hydro-Event-Detector excluded via the fork
# branch) then the app. The app's pyproject declares no deps (they live in its
# install.yml), so its runtime deps are installed explicitly. numpy stays 1.26.4 via
# overrides.txt. Reads S3 from ciroh-portal-assets/usgs-mrms via IRSA (env-configured).
COPY apps/mrms_usgs_events ${TETHYS_HOME}/apps/mrms_usgs_events
COPY apps/usgs_mrms_tethys_app ${TETHYS_HOME}/apps/usgs_mrms_tethys_app
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/apps/mrms_usgs_events && uv pip install . --overrides ${TETHYS_HOME}/overrides.txt && \
    uv pip install --overrides ${TETHYS_HOME}/overrides.txt \
      plotly mercantile boto3 pillow python-dotenv xarray zarr && \
    cd ${TETHYS_HOME}/apps/usgs_mrms_tethys_app/tethysapp-usgs_mrms && \
    uv pip install . --overrides ${TETHYS_HOME}/overrides.txt

# GDAL (osgeo) for the USGS-MRMS flood-alert step, which reads MRMS GRIB2 grids.
# Build the Python binding against the distro libgdal, pinned to gdal-config so its
# ABI matches the libgdal the runtime stage installs. numpy stays 1.26.4 via overrides.
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
  && rm -rf /var/lib/apt/lists/*
RUN --mount=type=cache,target=/cache/uv \
    uv pip install --overrides ${TETHYS_HOME}/overrides.txt "gdal==$(gdal-config --version)"

RUN chmod -R a+rX /opt/python /opt/conda \
  && chmod -R a+rwX ${VIRTUAL_ENV}/lib/python3.12/site-packages/tethysapp \
  && chmod -R a+rwX ${VIRTUAL_ENV}/lib/python3.12/site-packages/ciroh_plugins

FROM ${UVX_RUNTIME}

USER root
# git for submodule installs; gdal-bin provides the libgdal .so + GRIB2 driver the
# flood-alert osgeo binding loads at runtime (must match the builder's libgdal).
RUN apt-get update \
  && apt-get install -y --no-install-recommends git gdal-bin \
  && rm -rf /var/lib/apt/lists/*
USER 1000:1000

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
