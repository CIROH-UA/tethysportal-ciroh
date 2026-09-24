# Bakes the CIROH portal runtime pieces into the fimeval app image without
# touching the fimeval app repo (which merges to its own main): the OIDC login
# backend, the leading-slash-tolerant S3 static storage, and the CIROH-branded
# SSO-only login templates. The python modules must be importable by the web
# process and the provision job (collectstatic loads the static storage); the
# templates overwrite Tethys's installed copies so they win with no loader
# ordering games.
#
# Build from deploy/ so the shared files under oidc/ are in the build context:
#   docker build -t gioelkin/tethysapp-fimeval-gui:ciroh -f deploy/fimeval/Dockerfile deploy
ARG APP_IMAGE=gioelkin/tethysapp-fimeval-gui:latest
FROM ${APP_IMAGE}
ARG SP=/opt/conda/envs/tethys/lib/python3.12/site-packages
COPY oidc/ciroh_portal_oidc.py oidc/ciroh_portal_static.py ${SP}/
COPY oidc/templates/login.html oidc/templates/social_buttons.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/
COPY oidc/templates/accounts_base.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/base.html
