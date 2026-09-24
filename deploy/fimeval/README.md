# FIMeval on the CIROH cluster

FIMeval runs as a standalone single app Tethys portal, decoupled from the main
CIROH portal image. Its generic Helm chart lives in the app repo
(`Aquaveo/tethysapp-fimeval-gui`, `deploy/chart`); this directory holds only the
CIROH environment overlays.

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

Build the wrapper image (portal login backend, S3 static fix, and login templates,
baked over the app image), then upgrade:

```bash
docker build -t gioelkin/tethysapp-fimeval-gui:ciroh -f deploy/fimeval/Dockerfile deploy
docker push gioelkin/tethysapp-fimeval-gui:ciroh
helm upgrade --install fimeval \
  <app repo>/deploy/chart -n cirohportal -f deploy/fimeval/values-prod.yaml
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
