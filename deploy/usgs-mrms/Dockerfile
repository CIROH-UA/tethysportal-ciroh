# syntax=docker/dockerfile:1
# Build the standalone USGS-MRMS app on the CIROH Tethys base so the portal OIDC
# login backend, the S3 static fix, and the branded login templates ship in the
# image. Build context is the portal repo root. This app is two pieces:
#   App A  apps/usgs_mrms_tethys_app  (the Tethys app; the installable package is
#          nested at apps/usgs_mrms_tethys_app/tethysapp-usgs_mrms)
#   App B  apps/mrms_usgs_events      (a plain Python pip dependency imported by
#          App A at runtime; installed from the submodule, not deployed on its own)
# GDAL is required at runtime (App B calls gdal.Open on MRMS grib), so it is
# installed from apt and the matching gdal Python binding is added to the env.
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_7f91b35f42883e079a11e9d94429201d51bc8acd
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/usgs-mrms/requirements.txt ${TETHYS_HOME}/usgs-mrms-requirements.txt
COPY apps/mrms_usgs_events ${TETHYS_HOME}/apps/mrms_usgs_events
COPY apps/usgs_mrms_tethys_app ${TETHYS_HOME}/apps/usgs_mrms_tethys_app

# The app registers its controllers without an app prefix, so at single-app root
# its routes serve at "/flood-alert/", "/mrms/tiles/...", etc. But the built JS,
# some templates, and the tile/value URLs assembled in home.py hardcode the full
# multi-app prefix "/apps/usgs-mrms/", which 404s at "/". Rewrite that prefix to
# "/" in the installed package (public JS, templates, and controllers), then guard
# that none of those trees still carry it. Tests keep the literal and are skipped.
RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/usgs-mrms-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && uv pip install ${TETHYS_HOME}/apps/mrms_usgs_events \
    && uv pip install ${TETHYS_HOME}/apps/usgs_mrms_tethys_app/tethysapp-usgs_mrms \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3" \
    && PKG=/opt/conda/envs/tethys/lib/python3.12/site-packages/tethysapp/usgs_mrms \
    && grep -rlI '/apps/usgs-mrms/' "${PKG}/public" "${PKG}/templates" "${PKG}/controllers" | xargs -r sed -i 's#/apps/usgs-mrms/#/#g' \
    && ! grep -rnI '/apps/usgs-mrms/' "${PKG}/public" "${PKG}/templates" "${PKG}/controllers"

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda

USER 1000:1000
