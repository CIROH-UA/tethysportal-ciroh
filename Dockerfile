FROM ghcr.io/astral-sh/uv:trixie-slim

###############
# BUILD ARGS  #
###############
ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

###############
# ENVIRONMENT #
###############
ENV TETHYS_HOME="/usr/lib/tethys"
ENV TETHYS_LOG="/var/log/tethys"
ENV TETHYS_PERSIST="/var/lib/tethys_persist"
ENV TETHYS_APPS_ROOT="/var/www/tethys/apps"
ENV TETHYS_PORT=8000
ENV NGINX_PORT=8080
ENV POSTGRES_PASSWORD="pass"
ENV SKIP_DB_SETUP=false
ENV TETHYS_DB_ENGINE='django.db.backends.postgresql'
ENV TETHYS_DB_NAME='tethys_platform'
ENV TETHYS_DB_USERNAME="tethys_default"
ENV TETHYS_DB_PASSWORD="pass"
ENV TETHYS_DB_HOST="db"
ENV TETHYS_DB_PORT=5432
ENV TETHYS_DB_SUPERUSER="tethys_super"
ENV TETHYS_DB_SUPERUSER_PASS="pass"
ENV PORTAL_SUPERUSER_NAME=""
ENV PORTAL_SUPERUSER_EMAIL=""
ENV PORTAL_SUPERUSER_PASSWORD=""
ENV TETHYS_MANAGE="${TETHYS_HOME}/tethys/tethys_portal/manage.py"
ENV BASH_PROFILE=".bashrc"
ENV CONDA_HOME="/opt/conda"
ENV CONDA_ENV_NAME=tethys
ENV ENV_NAME=tethys
ENV ASGI_PROCESSES=1
ENV CLIENT_MAX_BODY_SIZE="75M"
ENV DEBUG="False"
ENV ALLOWED_HOSTS="\"[localhost, 127.0.0.1]\""
ENV CSRF_TRUSTED_ORIGINS="\"[http://localhost, http://127.0.0.1]\""
ENV BYPASS_TETHYS_HOME_PAGE="True"
ENV ADD_DJANGO_APPS="\"[]\""
ENV SESSION_WARN=1500
ENV SESSION_EXPIRE=1800
ENV STATIC_ROOT="${TETHYS_PERSIST}/static"
ENV STATIC_ROOT_CLEAR="True"
ENV WORKSPACE_ROOT="${TETHYS_PERSIST}/workspaces"
ENV MEDIA_ROOT="${TETHYS_PERSIST}/media"
ENV MEDIA_URL="/media/"
ENV QUOTA_HANDLERS="\"[]\""
ENV DJANGO_ANALYTICAL="\"{}\""
ENV ADD_BACKENDS="\"[]\""
ENV OAUTH_OPTIONS="\"{}\""
ENV CHANNEL_LAYERS_BACKEND="channels.layers.InMemoryChannelLayer"
ENV CHANNEL_LAYERS_CONFIG="\"{}\""
ENV RECAPTCHA_PRIVATE_KEY=""
ENV RECAPTCHA_PUBLIC_KEY=""
ENV OTHER_SETTINGS=""

ENV SITE_TITLE=""
ENV FAVICON=""
ENV BRAND_TEXT=""
ENV BRAND_IMAGE=""
ENV BRAND_IMAGE_HEIGHT=""
ENV BRAND_IMAGE_WIDTH=""
ENV BRAND_IMAGE_PADDING=""
ENV APPS_LIBRARY_TITLE=""
ENV PRIMARY_COLOR=""
ENV SECONDARY_COLOR=""
ENV PRIMARY_TEXT_COLOR=""
ENV PRIMARY_TEXT_HOVER_COLOR=""
ENV SECONDARY_TEXT_COLOR=""
ENV SECONDARY_TEXT_HOVER_COLOR=""
ENV BACKGROUND_COLOR=""
ENV COPYRIGHT=""
ENV HERO_TEXT=""
ENV BLURB_TEXT=""
ENV FEATURE_1_HEADING=""
ENV FEATURE_1_BODY=""
ENV FEATURE_1_IMAGE=""
ENV FEATURE_2_HEADING=""
ENV FEATURE_2_BODY=""
ENV FEATURE_2_IMAGE=""
ENV FEATURE_3_HEADING=""
ENV FEATURE_3_BODY=""
ENV FEATURE_3_IMAGE=""
ENV CALL_TO_ACTION=""
ENV CALL_TO_ACTION_BUTTON=""
ENV PORTAL_BASE_CSS=""
ENV HOME_PAGE_CSS=""
ENV APPS_LIBRARY_CSS=""
ENV ACCOUNTS_BASE_CSS=""
ENV LOGIN_CSS=""
ENV REGISTER_CSS=""
ENV USER_BASE_CSS=""
ENV HOME_PAGE_TEMPLATE=""
ENV APPS_LIBRARY_TEMPLATE=""
ENV LOGIN_PAGE_TEMPLATE=""
ENV REGISTER_PAGE_TEMPLATE=""
ENV USER_PAGE_TEMPLATE=""
ENV USER_SETTINGS_PAGE_TEMPLATE=""

ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysapp-tethys_dash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"

#########
# SETUP #
#########
USER root
RUN mkdir -p "${TETHYS_HOME}/tethys"
WORKDIR ${TETHYS_HOME}

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup \
  ; echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

##################################################
# LAYER 1: System packages (changes very rarely) #
##################################################
RUN rm -rf /var/lib/apt/lists/* \
  && apt-get clean \
  && apt-get update \
  && apt-get -y install curl gnupg2 ca-certificates lsb-release debian-archive-keyring \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | tee /etc/apt/keyrings/salt-archive-keyring.pgp \
  && curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | tee /etc/apt/sources.list.d/salt.sources \
  && apt-get update \
  && apt-get -y install bzip2 git nginx supervisor gcc salt-minion procps pv postgresql-client nodejs npm perl \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/nginx/sites-enabled/default

###########################################################
# LAYER 2: Python venv + tethys platform (changes rarely) #
###########################################################
ENV UV_PYTHON_PREFERENCE=only-managed
ENV UV_PYTHON_INSTALL_DIR=/opt/python
RUN uv python install 3.12

RUN mkdir -p ${CONDA_HOME}/envs/${CONDA_ENV_NAME} \
  && uv venv ${CONDA_HOME}/envs/${CONDA_ENV_NAME} --python 3.12 \
  && chmod -R a+rX ${CONDA_HOME}/envs/${CONDA_ENV_NAME} \
  && mkdir -p ${CONDA_HOME}/bin

ENV VIRTUAL_ENV=${CONDA_HOME}/envs/${CONDA_ENV_NAME}
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN uv pip install --no-cache \
    "tethys-platform @ git+https://github.com/tethysplatform/tethys.git" \
    channels-redis \
    psycopg2-binary \
    django-cors-headers \
    django-session-security \
    django-axes \
    django-gravatar2 \
    django-simple-captcha \
    django-mfa2 \
    django-recaptcha \
    "social-auth-app-django<5.5" \
    hs-restclient \
    python-jose \
    django-oauth-toolkit \
    django-tenants \
    arrow \
    isodate \
    django-termsandconditions \
    django-cookie-consent \
    django-analytical \
    django-json-widget \
    djangorestframework \
    djangorestframework-simplejwt \
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
    sqlalchemy==1.* \
  && uv pip install --no-cache "django>=4.2,<5" \
  && tethys gen portal_config

###########################################################
# LAYER 3: CIROH portal Python deps (changes occasionally)#
###########################################################
COPY requirements/piprequirements.txt ./piprequirements.txt

RUN uv pip install --no-cache -r piprequirements.txt \
    see \
    pywaterml \
    gstools \
    hydroeval \
    asyncio \
    hydroserverpy \
    "geoglows>=1.7.0" \
    area \
    utm \
    pyshp \
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

#################################################
# LAYER 4: Git-based plugins (changes rarely)   #
#################################################
RUN uv pip install --no-cache \
    git+https://github.com/FIRO-Tethys/ciroh_plugins.git@workshop-no-drought \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usace.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cnrfc.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_cw3e.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin-great_lakes_viewer.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_usgs_water_services.git \
    git+https://github.com/FIRO-Tethys/tethysdash_plugin_geoglows.git \
    git+https://github.com/FIRO-Tethys/RFC-Plugins.git

######################################################
# LAYER 5: Extensions + apps (rebuilds on code PRs)  #
######################################################
RUN mkdir -p ${TETHYS_PERSIST} ${TETHYS_APPS_ROOT} ${WORKSPACE_ROOT} ${MEDIA_ROOT} ${STATIC_ROOT} ${TETHYS_LOG}

RUN groupadd www \
  ; useradd -r -u 1011 -g www www \
  ; sed -i 's/^user.*/user www www;/' /etc/nginx/nginx.conf \
  ; sed -i "/^\[supervisord\]$/a user=www" /etc/supervisor/supervisord.conf \
  ; chown -R www: ${TETHYS_LOG} /run /var/log/supervisor /var/log/nginx /var/lib/nginx

ADD extensions ${TETHYS_HOME}/extensions
COPY apps ${TETHYS_HOME}/apps

RUN cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/ggst && uv pip install --no-cache . && \
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
    cd ${TETHYS_HOME}/apps/Water-Data-Explorer && uv pip install --no-cache . && \
    cd ${TETHYS_HOME}/apps/fimbench/reactapp && npm install && npm run build && \
    cd ${TETHYS_HOME}/apps/fimbench && uv pip install --no-cache .

###############
# SALT CONFIG #
###############
COPY salt/ /srv/salt/

# Clone tethys docker runtime files (run.sh, salt states) — not included in the PyPI package
RUN git clone --depth 1 --filter=blob:none --sparse https://github.com/tethysplatform/tethys.git /tmp/tethys-src && \
    cd /tmp/tethys-src && git sparse-checkout set docker && \
    cp /tmp/tethys-src/docker/run.sh ${TETHYS_HOME}/ && \
    cp /tmp/tethys-src/docker/liveness-probe.sh ${TETHYS_HOME}/ && \
    cp -n /tmp/tethys-src/docker/salt/*.sls /srv/salt/ 2>/dev/null && \
    rm -rf /tmp/tethys-src

RUN chmod +x ${TETHYS_HOME}/run.sh ${TETHYS_HOME}/liveness-probe.sh 2>/dev/null || true

# Ensure the www user can execute Python and all venv binaries
RUN chmod -R a+rX ${CONDA_HOME}/envs/${CONDA_ENV_NAME} && \
    chown -R www:www ${VIRTUAL_ENV}/lib/python3.12/site-packages/tethysapp/ \
                     ${VIRTUAL_ENV}/lib/python3.12/site-packages/ciroh_plugins/

# Symlink system binaries into venv so run.sh and salt states find them
RUN ln -sf /usr/bin/pg_isready ${VIRTUAL_ENV}/bin/pg_isready && \
    ln -sf /usr/bin/psql ${VIRTUAL_ENV}/bin/psql 2>/dev/null || true

# Create entrypoint shim that activates the venv environment
RUN printf '#!/bin/bash\nexport VIRTUAL_ENV=%s\nexport PATH="${VIRTUAL_ENV}/bin:${PATH}"\nexport CONDA_PREFIX="${VIRTUAL_ENV}"\nexport LD_LIBRARY_PATH="${VIRTUAL_ENV}/lib:${LD_LIBRARY_PATH}"\nexec "$@"\n' "${VIRTUAL_ENV}" > /usr/local/bin/_entrypoint.sh && \
    chmod +x /usr/local/bin/_entrypoint.sh

#########################
# CONFIGURE ENVIRONMENT #
#########################
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
ENV CONDA_PREFIX="${VIRTUAL_ENV}"
ENV LD_LIBRARY_PATH="${VIRTUAL_ENV}/lib"
VOLUME ["${TETHYS_PERSIST}", "${TETHYS_HOME}/keys"]
EXPOSE 80

WORKDIR ${TETHYS_HOME}
CMD bash run.sh
HEALTHCHECK --start-period=240s \
  CMD ./liveness-probe.sh
