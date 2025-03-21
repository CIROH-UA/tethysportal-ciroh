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
    pip install --no-deps --no-cache-dir ciroh-plugins && \
    micromamba clean --all --yes && \
    export PYTHON_SITE_PACKAGE_PATH=$(${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/python -m site | grep -a -m 1 "site-packages" | head -1 | sed 's/.$//' | sed -e 's/^\s*//' -e '/^$/d'| sed 's![^/]*$!!' | cut -c2-) &&\
    cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && python setup.py install && \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_app_store && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-metdataexplorer && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-sweml && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/gwdm && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/snow-inspector && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_dash && npm install && npm run build && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/Tethys-CSES && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/hydroshare_api_tethysapp && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/Water-Data-Explorer && tethys install -w -N -q && \
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
COPY config/tethys/gwdm/post_setup_gwdm.py ${TETHYS_HOME}

COPY salt/ /srv/salt/

# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1
RUN rm -Rf ~/.cache/pip && \
    micromamba install --yes -c conda-forge numpy==1.26.4 && \
    #important, this fixes th error of not finding pyrpoj database, it seems it is installed wiht both conda and pypi, so it has conflicting paths
    pip uninstall -y pyproj && \
    pip install --no-cache-dir --quiet pyproj && \
    pip uninstall -y pyogrio && \
    pip install --no-cache-dir --quiet pyogrio && \
    micromamba clean --all --yes

    
EXPOSE 80

CMD bash run.sh