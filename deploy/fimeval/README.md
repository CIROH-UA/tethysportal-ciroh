# FIMeval on the CIROH cluster

FIMeval runs as a standalone single app Tethys portal, decoupled from the main
CIROH portal image. Its Helm chart (tethys-app subchart plus the Dask cluster)
lives here in `chart/`, next to the CIROH environment overlays.

Production is live at `https://fimeval.tethys.ciroh.org` in the `cirohportal`
namespace: single app mode, scale to zero via KEDA, static and data on S3, and
sign in through the CIROH portal (see `../oidc`).

## Why its own database

The Tethys app registry is global to a database. When FIMeval shared the portal's
`tethys_platform` database it registered itself as a real app, and the portal
crashed trying to reverse a URL for a package it does not have installed. So
`values-prod.yaml` gives FIMeval its own `tethys_platform_fimeval` database on the
same RDS instance. Unified identity comes from the shared HydroShare login, not a
shared database.

## Deploy (prod)

CI publishes the CIROH base as `awiciroh/ciroh-tethys:builder` (see
`../ciroh-tethys`). Build the app on it so the login backend, S3 static fix, and
login templates ship in the app image (no wrapper), and upgrade:

```bash
# from this repo, with the app source passed as the `app` build context
APP=../apps/tethysapp-fimeval-gui   # or a git URL, e.g. https://github.com/Aquaveo/tethysapp-fimeval-gui.git#main

# backend tests (SQLite, moto); the runner exits 0 even on failure, so read the summary
docker build -f deploy/fimeval/Dockerfile --target test \
  --build-arg UVX_BUILDER=awiciroh/ciroh-tethys:builder \
  --build-context app=$APP -t fimeval:test deploy/fimeval
docker run --rm fimeval:test

docker build -f deploy/fimeval/Dockerfile \
  --build-arg UVX_BUILDER=awiciroh/ciroh-tethys:builder \
  --build-context app=$APP -t gioelkin/tethysapp-fimeval-gui:ciroh deploy/fimeval
docker push gioelkin/tethysapp-fimeval-gui:ciroh

helm dependency build deploy/fimeval/chart
helm upgrade --install fimeval \
  deploy/fimeval/chart -n cirohportal -f deploy/fimeval/values-prod.yaml
```

Create the `tethys_platform_fimeval` database once, owned by `tethys_default`,
before the first deploy. Apply `ingress.yaml` once to route
`fimeval.tethys.ciroh.org` on the shared `ciroh-apps` ALB to the KEDA interceptor.

## Post deploy settings

These live in the app database, so set them once per fresh database. Either use
Site Admin, App Settings, FIMeval GUI, or the CLI.

1. Custom setting `s3_bucket` = `ciroh-portal-assets` (S3 credentials stay blank so
   IRSA is used).
2. A Dask scheduler pointing at the in cluster scheduler, linked to the app's
   `dask_primary` scheduler setting. Give it a positive `timeout` (for example 60);
   a zero timeout triggers a Tethys client init error.

```bash
tethys schedulers create-dask -n fimeval_dask \
  -e tcp://fimeval-dask-scheduler:8786 -d fimeval-dask-scheduler:8787 -t 60 -b 0
```
