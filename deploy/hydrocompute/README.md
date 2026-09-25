# HydroCompute on the CIROH cluster

HydroCompute runs as a standalone single app Tethys portal, decoupled from the
main CIROH portal image. The app source is the `apps/tethysapp-hydrocompute`
submodule (`Aquaveo/tethysapp-hydrocompute`, branch `main`); this directory holds
the CIROH deploy artifacts.

HydroCompute is a server rendered app (package `hydrocompute`, root url `uihi`).
It has no custom app settings, no persistent store, no Dask, and reads no private
S3 data of its own. That makes it one of the simpler standalone apps: it deploys
the upstream `tethys-app` chart directly, with no wrapper chart.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives HydroCompute its own
`tethys_platform_hydrocompute` database on the same RDS instance. Unified identity
comes from signing in through the CIROH portal, not a shared database.

## Image

CI builds the app on the CIROH Tethys base and publishes
`awiciroh/tethysapp-hydrocompute`. The workflow
`.github/workflows/build_and_push_hydrocompute_image.yml` runs on any push or pull
request that touches `deploy/hydrocompute/` or the app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image. The app declares its own Python dependencies in its
`pyproject.toml`, so the build installs the app directly with `uv pip install .`
and needs no GDAL and no npm step.

The app vendors the HydroCompute JavaScript library as a nested git submodule under
`tethysapp/hydrocompute/public/HydroCompute`. The CI checkout initializes
submodules recursively so that nested library is present in the build context; if it
is missing the app page renders blank.

## Deploy (prod)

HydroCompute deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install hydrocompute oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/hydrocompute/values-prod.yaml
```

Create the `tethys_platform_hydrocompute` database once, owned by `tethys_default`,
before the first deploy. Apply `ingress.yaml` once to route
`hydrocompute.tethys.ciroh.org` on the shared `ciroh-apps` ALB to the KEDA
interceptor. The wildcard `*.tethys.ciroh.org` DNS record and ACM cert already
cover the subdomain, so no per app DNS or certificate is needed.

## Portal sign in (one time)

Register HydroCompute as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://hydrocompute.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`HYDROCOMPUTE_OIDC_CLIENT_ID` and `HYDROCOMPUTE_OIDC_CLIENT_SECRET`.

## Known runtime check

The app vendors its WASM and JS compute library through the nested git submodule
and loads Web Workers plus `.wasm` modules cross origin from the S3 static bucket.
After the first deploy, verify that `.wasm` files are served with the
`application/wasm` content type and that the bucket CORS policy allows the worker
`fetch` calls, or the compute workers fail to instantiate. HydroLang is loaded live
from the jsDelivr CDN, so confirm outbound access to jsDelivr resolves at runtime.
