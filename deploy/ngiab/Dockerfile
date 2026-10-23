# syntax=docker/dockerfile:1
# Build the NGIAB Visualizer on the CIROH Tethys base so the portal OIDC login
# backend, the S3 static fix, and the branded login templates ship in the image.
# Build context is the portal repo root, so the app comes from the apps/ngiab-client
# submodule (CIROH-UA/ngiab-client, package tethysapp.ngiab) and deps come from
# deploy/ngiab. DuckDB httpfs+aws extensions are baked in (the app LOADs them from
# DUCKDB_HOME at runtime with autoinstall/autoload off, so run ingest needs them
# present).
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/ngiab/requirements.txt ${TETHYS_HOME}/ngiab-requirements.txt
COPY apps/ngiab-client ${TETHYS_HOME}/apps/ngiab-client

RUN --mount=type=cache,target=/cache/uv \
    uv pip install -r ${TETHYS_HOME}/ngiab-requirements.txt \
    && uv pip install "gdal==$(gdal-config --version)" \
    && cd ${TETHYS_HOME}/apps/ngiab-client \
    && SETUPTOOLS_SCM_PRETEND_VERSION=0.1.0 uv pip install . \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3, duckdb"

RUN mkdir -p /opt/duckdb_extensions \
    && /opt/conda/envs/tethys/bin/python -c "import duckdb; c=duckdb.connect(); c.execute(\"SET extension_directory='/opt/duckdb_extensions'\"); c.execute('INSTALL httpfs'); c.execute('INSTALL aws'); print('duckdb extensions installed', duckdb.__version__)" \
    && /opt/conda/envs/tethys/bin/python -c "import pathlib,sys; e=list(pathlib.Path('/opt/duckdb_extensions').rglob('httpfs.duckdb_extension')); sys.exit(0 if e else 'httpfs extension missing after INSTALL')"

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal
COPY --from=builder /opt/duckdb_extensions /opt/duckdb_extensions
ENV DUCKDB_HOME=/opt/duckdb_extensions

USER 1000:1000
