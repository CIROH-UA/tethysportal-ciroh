# syntax=docker/dockerfile:1
ARG UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysapp-tethys_dash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"

WORKDIR ${TETHYS_HOME}

COPY requirements/piprequirements.txt ./piprequirements.txt
RUN uv pip install --no-cache -r piprequirements.txt \
    django-cors-headers \
    django-session-security \
    django-axes \
    django-gravatar2 \
    django-simple-captcha \
    django-mfa2 \
    django-recaptcha \
    hs-restclient \
    python-jose \
    django-oauth-toolkit \
    django-tenants \
    arrow \
    isodate \
    django-analytical \
    pyshp \
    docker \
    geoalchemy2 \
    plotly \
    bokeh \
    dask \
    condorpy \
    tethys-dask-scheduler \
    tethys-dataset-services \
    owslib \
    siphon \
    see \
    pywaterml \
    gstools \
    hydroeval \
    asyncio \
    hydroserverpy \
    "geoglows>=1.7.0" \
    area \
    utm \
    geopandas \
    shapely \
    xarray \
    rioxarray \
    "numpy==1.26.4" \
    pygithub \
    "gitpython==3.1.41" \
    requests \
    semver \
    pandas \
    geojson \
    setuptools \
    netcdf4 \
    cfunits \
    lxml \
    pyproj \
    xmltodict \
    suds-community \
    scipy \
    simplejson \
    pandarallel \
    matplotlib \
    pypng \
    httpx \
    geoserver-rest \
    boto3 \
    scikit-learn \
    djangorestframework \
    fiona \
    "pynhd==0.17.1" \
    "intake>=0.6.6" \
    "pygeoogc==0.17.1" \
    "pygeoutils==0.17.1" \
    "pygeohydro==0.17.1" \
    pyogrio \
    pytz \
    "django>=4.2,<5"

RUN uv pip install --no-cache \
    git+https://github.com/FIRO-Tethys/ciroh_plugins.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usace.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cnrfc.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cw3e.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin-great_lakes_viewer.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usgs_water_services.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_geoglows.git \
    git+https://github.com/FIRO-Tethys/RFC-Plugins.git

COPY extensions ${TETHYS_HOME}/extensions
COPY apps ${TETHYS_HOME}/apps
COPY requirements/overrides.txt ${TETHYS_HOME}/overrides.txt

RUN cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/tethysapp-sweml && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/snow-inspector && uv pip install --no-cache . && \
    mv ${DEV_REACT_CONFIG} ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_DEBUG_MODE.*#TETHYS_DEBUG_MODE = ${TETHYS_DEBUG_MODE}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_LOADER_DELAY.*#TETHYS_LOADER_DELAY = ${TETHYS_LOADER_DELAY}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_PORTAL_HOST.*#TETHYS_PORTAL_HOST = ${TETHYS_PORTAL_HOST}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_APP_ROOT_URL.*#TETHYS_APP_ROOT_URL = ${TETHYS_APP_ROOT_URL}#g" ${PROD_REACT_CONFIG} && \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_dash && npm install && npm run build && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/Tethys-CSES && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/fimbench/reactapp && npm install && npm run build && \
    cd ${TETHYS_HOME}/apps/fimbench && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/tethysapp-fimserve_viewer && uv pip install --no-cache . --overrides ${TETHYS_HOME}/overrides.txt

RUN chmod -R a+rX /opt/python /opt/conda \
  && chmod -R a+rwX ${VIRTUAL_ENV}/lib/python3.12/site-packages/tethysapp \
  && chmod -R a+rwX ${VIRTUAL_ENV}/lib/python3.12/site-packages/ciroh_plugins

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends git \
  && rm -rf /var/lib/apt/lists/*
USER 1000:1000

ENV POSTGIS_SERVICE_NAME="tethys_postgis"

COPY --from=builder /opt/python /opt/python
COPY --from=builder /opt/conda /opt/conda
COPY --chmod=0755 init.d/ /opt/portal/init.d/
COPY --chown=1000:1000 conf/portal_config.yml /config/portal_config.yml
