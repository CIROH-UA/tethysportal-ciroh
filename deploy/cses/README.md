# CSES on the CIROH cluster

The Community Streamflow Evaluation System (CSES) runs as a standalone single app
Tethys portal, decoupled from the main CIROH portal image. The app source is the
`apps/Tethys-CSES` submodule (`Aquaveo/Tethys-CSES`, branch `devcon`); this
directory holds the CIROH deploy artifacts.

CSES is a server rendered MapLayout app. It reads its data anonymously from the
public `streamflow-app-data` S3 bucket, so it needs no data credentials, no
`s3_bucket` setting, and no Dask. That makes it simpler than fimeval: it deploys
the upstream `tethys-app` chart directly, with no wrapper chart.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives CSES its own `tethys_platform_cses` database
on the same RDS instance. Unified identity comes from signing in through the CIROH
portal (see `../oidc`), not a shared database.

## Image

CI builds the app on the CIROH Tethys base and publishes
`awiciroh/tethysapp-cses`. The workflow
`.github/workflows/build_and_push_cses_image.yml` runs on any push or pull request
that touches `deploy/cses/` or the app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image. The app's runtime dependencies live in
`deploy/cses/requirements.txt` because the app's `pyproject.toml` declares none.

## Deploy (prod)

CSES deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install cses oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/cses/values-prod.yaml
```

Create the `tethys_platform_cses` database once, owned by `tethys_default`, before
the first deploy. Apply `ingress.yaml` once to route `cses.tethys.ciroh.org` on the
shared `ciroh-apps` ALB to the KEDA interceptor, and add the matching DNS CNAME
(the wildcard cert already covers the subdomain).

## Portal sign in (one time)

Register CSES as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://cses.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`CSES_OIDC_CLIENT_ID` and `CSES_OIDC_CLIENT_SECRET`.

## Known runtime check

CSES reads FileGDB and CSV data from `s3://streamflow-app-data` with geopandas and
boto3. The image installs GDAL plus `pyogrio`, `s3fs`, and `fsspec` to cover both
the GDAL `/vsis3` and fsspec read paths. Confirm the map layers load after the
first deploy; anonymous reads may need `AWS_NO_SIGN_REQUEST=YES` in the pod env if
geopandas routes an S3 read through GDAL.
