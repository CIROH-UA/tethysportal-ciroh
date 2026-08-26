"""Portal S3 storage backends."""

from storages.backends.s3 import S3Storage


class PortalStaticS3Storage(S3Storage):
    gzip = True
    gzip_content_types = (
        "text/css",
        "text/javascript",
        "application/javascript",
        "application/json",
        "application/wasm",
        "image/svg+xml",
        "text/plain",
        "application/xml",
        "text/xml",
    )

    def url(self, name, *args, **kwargs):
        if isinstance(name, str):
            name = name.lstrip("/")
        return super().url(name, *args, **kwargs)
