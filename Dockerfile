FROM tethysplatform/tethys-core:dev-py3.12-dj3.2 as base

#########################
# ADD APPLICATION FILES #
#########################
COPY apps ${TETHYS_HOME}/apps

COPY requirements/*.txt .

###################
# ADD THEME FILES #
###################
ADD extensions ${TETHYS_HOME}/extensions

ARG MAMBA_DOCKERFILE_ACTIVATE=1

#######################################
# INSTALL EXTENSIONS and APPLICATIONS #
#######################################


RUN pip install --no-cache-dir --quiet -r piprequirements.txt && \
    micromamba install --yes -c conda-forge --file requirements.txt && \
    micromamba clean --all --yes && \ 
    export PYTHON_SITE_PACKAGE_PATH=$(${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/python -m site | grep -a -m 1 "site-packages" | head -1 | sed 's/.$//' | sed -e 's/^\s*//' -e '/^$/d'| sed 's![^/]*$!!' | cut -c2-) &&\
    cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && python setup.py install && \
    cd ${TETHYS_HOME}/apps/Water-Data-Explorer && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/water_data_explorer.yml && \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_app_store && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/app_store.yml && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/ggst.yml && \
    cd ${TETHYS_HOME}/apps/tethysapp-metdataexplorer && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/metdataexplorer.yml && \
    cd ${TETHYS_HOME}/apps/tethysapp-swe && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/swe.yml && \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/hydrocompute.yml && \
    cd ${TETHYS_HOME}/apps/gwdm && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/gwdm.yml && \
    cd ${TETHYS_HOME}/apps/snow-inspector && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/snow-inspector.yml && \
    cd ${TETHYS_HOME}/apps/aquainsight && mv ${TETHYS_HOME}/apps/aquainsight/reactapp/config/development.env ${TETHYS_HOME}/apps/aquainsight/reactapp/config/production.env && npm install && npm run build-low-mem && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/aquainsight.yml && \
    cd ${TETHYS_HOME}/apps/Tethys-CSES && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/community_streamflow_evaluation_system.yml && \
    cd ${TETHYS_HOME}/apps/hydroshare_api_tethysapp && tethys install -w -N -q && cp install.yml $PYTHON_SITE_PACKAGE_PATH/site-packages/hydroshare_api_tethysapp.yml && \
    rm -rf /var/lib/apt/lists/* && \
    find -name '*.a' -delete && \
    rm -rf ${CONDA_HOME}/envs/${CONDA_ENV_NAME}/conda-meta && \
    rm -rf ${CONDA_HOME}/envs/${CONDA_ENV_NAME}/include && \
    find -name '__pycache__' -type d -exec rm -rf '{}' '+' && \
    rm -rf $PYTHON_SITE_PACKAGE_PATH/site-packages/pip $PYTHON_SITE_PACKAGE_PATH/idlelib $PYTHON_SITE_PACKAGE_PATH/ensurepip && \
    find $PYTHON_SITE_PACKAGE_PATH/site-packages/scipy -name 'tests' -type d -exec rm -rf '{}' '+' && \
    find $PYTHON_SITE_PACKAGE_PATH/site-packages/numpy -name 'tests' -type d -exec rm -rf '{}' '+' && \
    find $PYTHON_SITE_PACKAGE_PATH/site-packages/pandas -name 'tests' -type d -exec rm -rf '{}' '+' && \
    find $PYTHON_SITE_PACKAGE_PATH/site-packages -name '*.pyx' -delete && \
    rm -rf $PYTHON_SITE_PACKAGE_PATH/uvloop/loop.c

FROM tethysplatform/tethys-core:dev-py3.12-dj3.2 as build

# Copy Conda env from base image
COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}
COPY config/tethys/asgi_supervisord.conf ${TETHYS_HOME}/asgi_supervisord.conf
COPY config/tethys/supervisord.conf /etc/supervisor/supervisord.conf
COPY config/tethys/update_tethys_apps.py ${TETHYS_HOME}
COPY config/tethys/update_proxy_apps.py ${TETHYS_HOME}
COPY config/tethys/update_state.sh ${TETHYS_HOME}
COPY config/tethys/gwdm/post_setup_gwdm.py ${TETHYS_HOME}

COPY salt/ /srv/salt/

# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1
RUN rm -Rf ~/.cache/pip && \
    micromamba install --yes -c conda-forge numpy==1.26.4 && \
    micromamba clean --all --yes  
EXPOSE 80

CMD bash run.sh