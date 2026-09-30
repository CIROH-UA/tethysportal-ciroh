# CIROH Tethys builder base

A CIROH flavored Tethys builder image: `tethys-uvx:builder` plus the CIROH portal
runtime pieces from `../oidc` (the OIDC login backend, the leading slash tolerant
S3 static storage, and the branded sign in templates). CIROH standalone apps build
on this so those pieces ship inside every app image, and there is no per app
wrapper image to build or track.

It is a CIROH image built from Aquaveo's generic `tethys-uvx`; the CIROH code does
not go into `tethys-uvx` itself.

## Why the builder stage, not the runtime

The app Dockerfiles are two stage and end with `COPY --from=builder /opt/conda
/opt/conda`, which overwrites the runtime image's `site-packages`. Anything added
to a runtime based image is wiped by that copy. So the modules and templates must
live in the builder's `/opt/conda` to survive into the final image, which is why
this base is built from `tethys-uvx:builder`.

The app Dockerfile's runtime base (`UVX_RUNTIME`) does not need to change; the
CIROH files ride in through the builder's `/opt/conda`.

## Build

CI builds and publishes this base to Docker Hub as `awiciroh/ciroh-tethys`. The
workflow `.github/workflows/build_and_push_ciroh_tethys_base.yml` runs on any push
that touches `deploy/ciroh-tethys/` or `deploy/oidc/`, and on demand via
`workflow_dispatch` (where the `tethys-uvx` base image can be set). It tags
`:builder` (floating) and `:builder_<sha>` (immutable); build apps against the
immutable tag for reproducibility.

To build it by hand, run from `deploy/` so the shared files under `oidc/` are in
the build context:

```bash
docker build -t awiciroh/ciroh-tethys:builder \
  --build-arg TETHYS_UVX_BUILDER=ghcr.io/aquaveo/tethys-uvx:builder \
  -f ciroh-tethys/Dockerfile deploy
docker push awiciroh/ciroh-tethys:builder
```

## How apps consume it

App Dockerfiles already parameterize their base as `ARG UVX_BUILDER=...`, so no app
repo changes are needed. CIROH builds an app against this base with a build arg:

```bash
docker build --build-arg UVX_BUILDER=awiciroh/ciroh-tethys:builder \
  -t <app-image> .
```

The resulting app image already contains `ciroh_portal_oidc`,
`LeadingSlashS3Storage`, and the branded login, so the app's `values-prod.yaml`
keeps referencing them (`AUTHENTICATION_BACKENDS`, `STORAGES.staticfiles.BACKEND`)
and points `image` at the app image directly. No `:ciroh` wrapper.

## Migrating an app off the wrapper

For an app currently deployed via a wrapper (fimeval today):

1. Build and push this base.
2. Rebuild the app image with `--build-arg UVX_BUILDER=<this base>`.
3. In the app overlay, point `image` at the app image and drop the `:ciroh` tag.
4. Delete the app's `deploy/<app>/Dockerfile` wrapper.

## Note on the templates

The modules are standalone files, so an app's `uv pip install .` never touches
them. The templates overwrite Tethys's own copies, so they survive only as long as
the app build does not reinstall `tethys_portal` over them. CIROH apps share this
`tethys-uvx` base, so Tethys is already satisfied and is not reinstalled. If an app
ever pins a different Tethys, keep the templates as a thin overlay for that app
instead.
