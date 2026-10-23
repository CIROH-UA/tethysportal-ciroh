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

COPY extensions ${TETHYS_HOME}/extensions
RUN --mount=type=cache,target=/cache/uv \
    cd ${TETHYS_HOME}/extensions/tethysext-ciroh_theme && uv pip install .

# Override two core Tethys templates (portal home + app library) with the CIROH
# versions. Django's filesystem loader searches tethys_portal/templates ahead of the
# app-directory templates, so copying the overrides there wins over the core ones
# (same mechanism as the OIDC login override). Shipping them only inside the
# extension is not enough: the extension templates never beat core in the loader order.
RUN TP="$(${VIRTUAL_ENV}/bin/python -c 'import tethys_portal,os;print(os.path.join(os.path.dirname(tethys_portal.__file__),"templates"))')" \
 && CT="$(${VIRTUAL_ENV}/bin/python -c 'import tethysext.ciroh_theme,os;print(os.path.join(os.path.dirname(tethysext.ciroh_theme.__file__),"templates"))')" \
 && mkdir -p "$TP/tethys_apps" "$TP/tethys_portal" \
 && cp "$CT/tethys_apps/app_library.html" "$TP/tethys_apps/app_library.html" \
 && cp "$CT/tethys_portal/home.html" "$TP/tethys_portal/home.html" \
 && cp "$CT/header.html" "$TP/header.html" \
 && echo "CIROH template overrides installed into $TP"

# The viewer/data apps (sweml, hydrocompute, snow-inspector, tethysdash, cses,
# fimbench, fimserve_viewer, usgs-mrms, hydro-correlation-tool, nrds, ngiab) now
# run as standalone deployments (deploy/<app>/ overlays + their own images), so
# they are intentionally NOT installed here. This keeps the portal a lean hub: the
# OIDC provider, the CIROH theme, and the app library of ProxyApp cards that link
# out to each app's subdomain.

RUN chmod -R a+rX /opt/python /opt/conda

FROM ${UVX_RUNTIME}

ENV POSTGIS_SERVICE_NAME="tethys_postgis"

COPY --from=builder /opt/python /opt/python
COPY --from=builder /opt/conda /opt/conda
COPY --chown=1000:1000 conf/portal_config.yml /config/portal_config.yml
# Explicit modes so a checkout with private (0600) files still yields files the
# portal user (1000) can read. Keep the 0755 copies first: --chmod also applies to
# the /opt/portal directory it creates, and a 0644 directory can't be entered.
# Portal-owned config hook: OAuth secrets from env (base portal-config.sh runs it).
COPY --chmod=0755 conf/portal-config.d/ /opt/portal/portal-config.d/
# Portal-owned provision hook: link app stores + syncstores (base provision.sh runs it).
COPY --chmod=0755 conf/init.d/ /opt/portal/init.d/
# Portal-owned S3 storage backend (base no longer ships it); on PYTHONPATH=/opt/portal.
COPY --chmod=0644 conf/portal_storage.py /opt/portal/portal_storage.py
# Portal-owned OIDC validator: adds preferred_username/name/email claims so apps
# show the real name instead of the sub UUID; on PYTHONPATH=/opt/portal.
COPY --chmod=0644 conf/portal_oidc.py /opt/portal/portal_oidc.py

# NOTE: the DB bootstrap + portal seed are DEV-ONLY tools and live in dev/ — they are
# deliberately NOT baked into this image. The docker-compose dev stack mounts dev/ and
# runs them; prod provisioning is migrate + syncstores (chart hooks) + DBA SQL on RDS
# (README §2.5). CMD (serve.sh) is inherited from base.
