# Bakes the CIROH portal runtime modules into the fimeval app image without
# touching the fimeval app repo (which merges to its own main): the OIDC login
# backend and the leading-slash-tolerant S3 static storage. Both must be
# importable by the web process and the provision job (collectstatic loads the
# static storage), so they are copied into site-packages rather than mounted.
#
# Build from deploy/ so the shared modules under oidc/ are in the build context:
#   docker build -t gioelkin/tethysapp-fimeval-gui:ciroh -f deploy/fimeval/Dockerfile deploy
ARG APP_IMAGE=gioelkin/tethysapp-fimeval-gui:latest
FROM ${APP_IMAGE}
COPY oidc/ciroh_portal_oidc.py oidc/ciroh_portal_static.py \
     /opt/conda/envs/tethys/lib/python3.12/site-packages/
