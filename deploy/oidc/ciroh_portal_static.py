"""Leading-slash-tolerant S3 static storage for CIROH standalone apps.

Vanilla Tethys chrome emits static paths with a leading slash, both hardcoded in
templates (e.g. accounts/base.html: {% static '/tethys_portal/css/account_form.min.css' %})
and as default site-setting values (the default favicon). django-storages' S3
backend runs every name through safe_join, which rejects an absolute path, so the
Tethys login and error pages 500 under s3Static. Stripping the leading slash
before the base backend sees it makes those paths resolve to the objects
collectstatic already uploaded. Lives in the tethysportal-ciroh deploy overlay,
not in any app repo, and is baked into the app image alongside the OIDC backend.
"""
from storages.backends.s3 import S3Storage


class LeadingSlashS3Storage(S3Storage):
    def _normalize_name(self, name):
        return super()._normalize_name(name.lstrip("/"))
