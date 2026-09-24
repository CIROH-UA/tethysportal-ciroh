ARG TETHYS_UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder
FROM ${TETHYS_UVX_BUILDER}
ARG SP=/opt/conda/envs/tethys/lib/python3.12/site-packages
COPY oidc/ciroh_portal_oidc.py oidc/ciroh_portal_static.py ${SP}/
COPY oidc/templates/login.html oidc/templates/social_buttons.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/
COPY oidc/templates/accounts_base.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/base.html
