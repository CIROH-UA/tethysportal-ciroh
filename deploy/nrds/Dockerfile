# syntax=docker/dockerfile:1
# Build the NRDS client on the CIROH Tethys base so the portal OIDC login backend,
# the S3 static fix, and the branded login templates ship in the image. Build
# context is the portal repo root, so the app comes from the apps/nrds-client
# submodule (CIROH-UA/nrds-client, package tethysapp.nrds) and deps come from
# deploy/nrds. The slim hydrofabric index is gitignored/generated, so it must be
# built here before install (else the parquet 403s from S3 at runtime).
ARG UVX_BUILDER=awiciroh/ciroh-tethys:builder_639eda75d3773cbd01655294c4b09d39ce734dff
ARG UVX_RUNTIME=ghcr.io/aquaveo/tethys-uvx:runtime-base

FROM ${UVX_BUILDER} AS builder

ENV UV_CACHE_DIR=/cache/uv

WORKDIR ${TETHYS_HOME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgdal-dev gdal-bin g++ \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/nrds/overrides.txt ${TETHYS_HOME}/overrides.txt
COPY apps/nrds-client ${TETHYS_HOME}/apps/nrds-client

RUN --mount=type=cache,target=/cache/uv \
    uv pip install --overrides ${TETHYS_HOME}/overrides.txt pyarrow fsspec s3fs xarray geopandas \
    && cd ${TETHYS_HOME}/apps/nrds-client \
    && /opt/conda/envs/tethys/bin/python scripts/build_slim_index.py \
    && SETUPTOOLS_SCM_PRETEND_VERSION=0.1.0 uv pip install . --overrides ${TETHYS_HOME}/overrides.txt \
    && /opt/conda/envs/tethys/bin/python -c "import storages, boto3" \
    && /opt/conda/envs/tethys/bin/python -c "import pathlib,sys,tethysapp.nrds as a; p=pathlib.Path(a.__file__).parent/'public/data/hydrofabric_index_slim.parquet'; sys.exit(0) if p.is_file() and p.stat().st_size>30_000_000 else sys.exit('slim index missing/too small in installed package: %s'%p)"

FROM ${UVX_RUNTIME}

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends gdal-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 --from=builder /opt/python /opt/python
COPY --chown=1000:1000 --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/portal /opt/portal

USER 1000:1000
