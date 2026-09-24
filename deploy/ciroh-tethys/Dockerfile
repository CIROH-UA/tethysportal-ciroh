ARG TETHYS_UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder
FROM ${TETHYS_UVX_BUILDER}
ARG SP=/opt/conda/envs/tethys/lib/python3.12/site-packages
# ciroh_portal_static.py imports django-storages, so the base must ship it;
# otherwise every app using LeadingSlashS3Storage 500s with "No module named
# 'storages'". Install it here, not per app.
RUN uv pip install "django-storages>=1.14"
COPY oidc/ciroh_portal_oidc.py oidc/ciroh_portal_static.py ${SP}/
COPY oidc/templates/login.html oidc/templates/social_buttons.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/
COPY oidc/templates/accounts_base.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/base.html
# Fail the build if the baked static backend's dependency is missing.
RUN /opt/conda/envs/tethys/bin/python -c "import storages"
