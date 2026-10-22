ARG TETHYS_UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder
FROM ${TETHYS_UVX_BUILDER}
ARG SP=/opt/conda/envs/tethys/lib/python3.12/site-packages
# ciroh_portal_static.py imports storages.backends.s3, which needs both
# django-storages and boto3, so the base must ship them; otherwise every app
# using LeadingSlashS3Storage 500s ("No module named 'storages'"/'boto3'). The
# [s3] extra pulls boto3. Install here, not per app.
RUN uv pip install "django-storages[s3]>=1.14"
COPY --chmod=0644 oidc/ciroh_portal_oidc.py oidc/ciroh_portal_static.py ${SP}/
COPY --chmod=0644 oidc/templates/login.html oidc/templates/social_buttons.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/
COPY --chmod=0644 oidc/templates/accounts_base.html \
     ${SP}/tethys_portal/templates/tethys_portal/accounts/base.html
# Fail the build if the baked static backend's dependencies are missing.
RUN /opt/conda/envs/tethys/bin/python -c "import storages, boto3"
