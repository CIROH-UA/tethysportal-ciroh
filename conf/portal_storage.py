"""Portal S3 storage backends."""

from storages.backends.s3 import S3Storage


class PortalStaticS3Storage(S3Storage):
    def url(self, name, *args, **kwargs):
        if isinstance(name, str):
            name = name.lstrip("/")
        return super().url(name, *args, **kwargs)
