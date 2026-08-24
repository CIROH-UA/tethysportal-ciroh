"""Portal S3 storage backends."""

from storages.backends.s3 import S3Storage


class PortalStaticS3Storage(S3Storage):
    # Static is served S3-direct (no CloudFront), so S3 does no on-the-fly
    # compression — JS/CSS/wasm bundles ship raw (e.g. nrds main.js is 3.4 MB).
    # Gzip them on upload; browsers decode Content-Encoding: gzip transparently.
    # Allowlist ONLY text-y types: parquet/pmtiles/fonts/images are octet-stream
    # and must stay uncompressed — they don't shrink AND the apps do HTTP range
    # reads on them (duckdb-wasm, PMTiles), which a gzip-encoded object breaks.
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
