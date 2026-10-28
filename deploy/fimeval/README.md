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

The image builds on the CIROH base (`awiciroh/ciroh-tethys:builder_<sha>`, see
`../ciroh-tethys`), so the login backend, S3 static fix, and login templates ship
in the app image (no wrapper).

The app comes from the `apps/tethysapp-fimeval-gui` submodule
(`Aquaveo/tethysapp-fimeval-gui`, tracking `main`). CI (`build_push_app_images`)
builds and tests the image when `deploy/fimeval/` or the submodule changes, and
pushes `awiciroh/tethysapp-fimeval-gui:<portal sha>`. To ship app changes, bump
the submodule in a portal PR (`git submodule update --remote
apps/tethysapp-fimeval-gui`, then commit it). To build locally:

```bash
# from this repo, with the submodule checked out
git submodule update --init apps/tethysapp-fimeval-gui

# backend tests (SQLite, moto); the runner exits 0 even on failure, so read the summary
docker build -f deploy/fimeval/Dockerfile --target test -t fimeval:test .
docker run --rm fimeval:test

# local image only; deployed images come from CI (awiciroh/tethysapp-fimeval-gui)
docker build -f deploy/fimeval/Dockerfile -t fimeval:local .

helm dependency build deploy/fimeval/chart
helm upgrade --install fimeval \
  deploy/fimeval/chart -n cirohportal -f deploy/fimeval/values-prod.yaml
```

After a change to the Dask cluster's spec (image, resources, env), recreate the
cluster. The Dask operator applies only worker-count changes to a running
cluster, so without this the workers keep the old app code and jobs from the new
web pod fail on them. Deploys through `deploy_apps` do this by themselves; after a
`helm upgrade` by hand, do it yourself. It interrupts running jobs, so do it when
none are running:

```
kubectl -n cirohportal delete daskcluster fimeval-dask
helm upgrade fimeval deploy/fimeval/chart -n cirohportal -f deploy/fimeval/values-prod.yaml
kubectl -n cirohportal get deploy | grep fimeval-dask   # same image as the web pod
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
