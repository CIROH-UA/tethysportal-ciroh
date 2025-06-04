FROM tethysplatform/tethys-core:dev-py3.10-dj4.2 as base

ARG TETHYS_PORTAL_HOST=""
ARG TETHYS_APP_ROOT_URL="/apps/tethysdash/"
ARG TETHYS_LOADER_DELAY="500"
ARG TETHYS_DEBUG_MODE="false"

###############################
# DEFAULT ENVIRONMENT VARIABLES
###############################

ENV TETHYS_DASH_APP_SRC_ROOT=${TETHYS_HOME}/apps/tethysapp-tethys_dash
ENV DEV_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/development.env"
ENV PROD_REACT_CONFIG="${TETHYS_DASH_APP_SRC_ROOT}/reactapp/config/production.env"
ENV NGINX_PORT=8080

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


RUN echo "Start Now 2" && \ 
    pip install --no-cache-dir --quiet -r piprequirements.txt && \
    micromamba install --yes -c conda-forge --file requirements.txt && \
    pip install git+https://github.com/FIRO-Tethys/ciroh_plugins.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin_usace.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin_cnrfc.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin_cw3e.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin-great_lakes_viewer.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin_usgs_water_services.git --no-cache-dir && \
    pip install git+https://github.com/FIRO-Tethys/tethysdash_plugin_geoglows.git --no-cache-dir && \
    micromamba clean --all --yes && \
    export PYTHON_SITE_PACKAGE_PATH=$(${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/python -m site | grep -a -m 1 "site-packages" | head -1 | sed 's/.$//' | sed -e 's/^\s*//' -e '/^$/d'| sed 's![^/]*$!!' | cut -c2-) &&\
    cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && python setup.py install && \
    cd ${TETHYS_HOME}/apps/ggst && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-sweml && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/tethysapp-hydrocompute && tethys install -w -N -q && \
    cd ${TETHYS_HOME}/apps/snow-inspector && tethys install -w -N -q && \
    mv ${DEV_REACT_CONFIG} ${PROD_REACT_CONFIG} && \

    sed -i "s#TETHYS_DEBUG_MODE.*#TETHYS_DEBUG_MODE = ${TETHYS_DEBUG_MODE}#g" ${PROD_REACT_CONFIG}  && \
    sed -i "s#TETHYS_LOADER_DELAY.*#TETHYS_LOADER_DELAY = ${TETHYS_LOADER_DELAY}#g" ${PROD_REACT_CONFIG} && \
    sed -i "s#TETHYS_PORTAL_HOST.*#TETHYS_PORTAL_HOST = ${TETHYS_PORTAL_HOST}#g" ${PROD_REACT_CONFIG}  && \
    sed -i "s#TETHYS_APP_ROOT_URL.*#TETHYS_APP_ROOT_URL = ${TETHYS_APP_ROOT_URL}#g" ${PROD_REACT_CONFIG} && \
  
    cd ${TETHYS_HOME}/apps/tethysapp-tethys_dash && npm install && npm run build && tethys install -w -N -q && \
    
    cd ${TETHYS_HOME}/apps/Tethys-CSES && tethys install -w -N -q && \
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

FROM tethysplatform/tethys-core:dev-py3.10-dj4.2 as build

ENV NGINX_PORT=8080

# Copy Conda env from base image
COPY --chown=www:www --from=base ${CONDA_HOME}/envs/${CONDA_ENV_NAME} ${CONDA_HOME}/envs/${CONDA_ENV_NAME}

COPY salt/ /srv/salt/

# Activate tethys conda environment during build
ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN rm -Rf ~/.cache/pip && \
    micromamba install --yes -c conda-forge numpy==1.26.4 && \
    #fix error # 3
    pip uninstall -y pyproj && \
    pip install --no-cache-dir --quiet pyproj && \
    pip uninstall -y pyogrio && \
    pip install --no-cache-dir --quiet pyogrio && \
    #fix error # 4
    pip uninstall -y dask && \
    pip install --no-cache-dir dask && \
    pip install --upgrade dask && \
    #fix error # 1
    pip uninstall -y importlib-metadata && \
    pip install --no-cache-dir --quiet importlib-metadata && \
    micromamba clean --all --yes && \
    #fix error # 2
    export PYTHON_SITE_PACKAGE_PATH=$(${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/python -m site | grep -a -m 1 "site-packages" | head -1 | sed 's/.$//' | sed -e 's/^\s*//' -e '/^$/d'| sed 's![^/]*$!!' | cut -c2-) &&\
    ln -s $PYTHON_SITE_PACKAGE_PATH/site-packages/daphne/twisted/plugins/fd_endpoint.py $PYTHON_SITE_PACKAGE_PATH/site-packages/twisted/plugins/fd_endpoint.py

EXPOSE 80

CMD bash run.sh


# Errors notes

# 1
# Traceback (most recent call last):
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/tethysapp/tethysdash/collect_plugin_thumbnails.py", line 100, in <module>
#     main()
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/tethysapp/tethysdash/collect_plugin_thumbnails.py", line 80, in main
#     copy_plugin_images(plugins, static_plugin_images)
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/tethysapp/tethysdash/collect_plugin_thumbnails.py", line 20, in copy_plugin_images
#     mod = importlib.import_module(module)
#   File "/opt/conda/envs/tethys/lib/python3.10/importlib/__init__.py", line 126, in import_module
#     return _bootstrap._gcd_import(name[level:], package, level)
#   File "<frozen importlib._bootstrap>", line 1050, in _gcd_import
#   File "<frozen importlib._bootstrap>", line 1027, in _find_and_load
#   File "<frozen importlib._bootstrap>", line 1006, in _find_and_load_unlocked
#   File "<frozen importlib._bootstrap>", line 688, in _load_unlocked
#   File "<frozen importlib._bootstrap_external>", line 883, in exec_module
#   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/ciroh_plugins/nwmps/service.py", line 4, in <module>
#     import pygeoutils as geoutils
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/pygeoutils/__init__.py", line 10, in <module>
#     from pygeoutils._utils import get_gtiff_attrs, get_transform, transform2tuple, xd_write_crs
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/pygeoutils/_utils.py", line 14, in <module>
#     import rioxarray._io as rxr
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/rioxarray/__init__.py", line 5, in <module>
#     import rioxarray.raster_array  # noqa
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/rioxarray/raster_array.py", line 39, in <module>
#     from rioxarray.raster_writer import RasterioWriter, _ensure_nodata_dtype
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/rioxarray/raster_writer.py", line 20, in <module>
#     import dask.array
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/dask/__init__.py", line 4, in <module>
#     from dask._expr import Expr, HLGExpr, LLGExpr, SingletonExpr
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/dask/_expr.py", line 15, in <module>
#     from dask._task_spec import Task, convert_legacy_graph
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/dask/_task_spec.py", line 65, in <module>
#     from dask.sizeof import sizeof
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/dask/sizeof.py", line 318, in <module>
#     _register_entry_point_plugins()
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/dask/sizeof.py", line 308, in _register_entry_point_plugins
#     for entry_point in importlib_metadata.entry_points(group="dask.sizeof"):
# AttributeError: module 'importlib_metadata' has no attribute 'entry_points'

#2.
#   File "/opt/conda/envs/tethys/lib/python3.10/site-packages/twisted/internet/endpoints.py", line 1779, in _matchPluginToPrefix
#     raise ValueError(f"Unknown endpoint type: '{endpointType}'")
# ValueError: Unknown endpoint type: 'fd'

#3.

#important, this fixes th error of not finding pyrpoj database, it seems it is installed wiht both conda and pypi, so it has conflicting paths

#4.

# Failed to retrieve data
# module 'dask' has no attribute 'utils'