# FIMbench on the CIROH cluster

FIMbench runs as a standalone single app Tethys portal, decoupled from the main
CIROH portal image. The app source is the `apps/fimbench` submodule
(`Aquaveo/fimbench-gui`, branch `main`); this directory holds the CIROH deploy
artifacts.

FIMbench is a React single page app that reads benchmark FIM data and map tiles
directly from a public S3 bucket (`sdmlab.s3.amazonaws.com`) in the browser, so it
needs no data credentials, no persistent store, and no Dask. It deploys the
upstream `tethys-app` chart directly, with no wrapper chart.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives FIMbench its own `tethys_platform_fimbench`
database on the same RDS instance. Unified identity comes from signing in through
the CIROH portal (see `../oidc`), not a shared database.

## Image

CI builds the app (React build with Vite, then the Tethys app) on the CIROH Tethys
base and publishes `awiciroh/tethysapp-fimbench`. The workflow
`.github/workflows/build_and_push_fimbench_image.yml` runs on any push or pull
request that touches `deploy/fimbench/` or the app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image.

## Deploy (prod)

FIMbench deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install fimbench oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/fimbench/values-prod.yaml
```

Create the `tethys_platform_fimbench` database once, owned by `tethys_default`,
before the first deploy. Apply `ingress.yaml` once to route
`fimbench.tethys.ciroh.org` on the shared `ciroh-apps` ALB to the KEDA interceptor.

## Portal sign in (one time)

Register FIMbench as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://fimbench.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`FIMBENCH_OIDC_CLIENT_ID` and `FIMBENCH_OIDC_CLIENT_SECRET`.

## Post deploy settings

FIMbench declares four required custom settings that point the SPA at its public
data. Set them once per fresh database in Site Admin, App Settings, FIMbench GUI,
or the CLI. The values below are derived from the app's own download scripts;
confirm them with the FIMbench maintainer.

| Setting | Example value |
|---------|---------------|
| `s3_allowed_host` | `sdmlab.s3.amazonaws.com` |
| `s3_bucket_url` | `https://sdmlab.s3.amazonaws.com/FIM_Database/FIM_Viz` |
| `s3_catalog_key` | `catalog_core.json` |
| `s3_viz_tiles` | `https://sdmlab.s3.amazonaws.com/FIM_Database/FIM_Viz/tiles/{z}/{x}/{y}.png` |

Until all four are set, the app is not `configured` and the map has no data.

## Known runtime check

The React CSS and docs reference some statics with absolute `/static/fimbench_gui/`
paths. Under `s3Static` these are served from S3; confirm the header, sidebar, and
docs images load after the first deploy. If any 403, they are handled the same way
as the rest of the static pipeline (collectstatic uploads the app's `public/` tree,
which uses a recursive `public/**/*` package-data glob, so nothing is dropped).
