# USGS-MRMS on the CIROH cluster

The USGS-MRMS Flood Explorer runs as a standalone single app Tethys portal,
decoupled from the main CIROH portal image. It is a server rendered app (no React)
that visualizes MRMS rainfall, USGS water stage, and hydrologic flood alerts across
US basins. The app source is two submodules; this directory holds the CIROH deploy
artifacts.

The app is made of two pieces:

* `apps/usgs_mrms_tethys_app` is the Tethys app. Its installable package is nested
  one level down at `apps/usgs_mrms_tethys_app/tethysapp-usgs_mrms` (that is where
  `pyproject.toml` and `tethysapp/usgs_mrms/` live).
* `apps/mrms_usgs_events` is a plain Python package (peak extraction, basin
  delineation, MRMS download, Zarr conversion) that the Tethys app imports at
  runtime. It is installed as a pip dependency inside the same image, not deployed
  on its own.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares the
portal's `tethys_platform` database registers itself as a real app and crashes the
portal. `values-prod.yaml` gives USGS-MRMS its own `tethys_platform_usgs_mrms`
database on the same RDS instance. Unified identity comes from signing in through
the CIROH portal (see `../oidc`), not a shared database.

## Image

CI builds the app on the CIROH Tethys base and publishes
`awiciroh/tethysapp-usgs-mrms`. The workflow
`.github/workflows/build_and_push_usgs-mrms_image.yml` runs on any push or pull
request that touches `deploy/usgs-mrms/` or either app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates ship
inside the image. GDAL is required at runtime (the events package calls
`gdal.Open` on MRMS grib), so the build installs `gdal-bin` plus a matching gdal
Python binding. Runtime dependencies live in `deploy/usgs-mrms/requirements.txt`
because neither pyproject pins them for the uvx build; that file is the union of the
Tethys app conda deps and the events package deps.

### Single app path rewrite

The app registers its controllers without an app prefix, so at single app root its
routes serve at `/flood-alert/`, `/mrms/tiles/...`, and so on. But the built JS,
some templates, and the tile and value URLs assembled in `controllers/home.py`
hardcode the multi-app prefix `/apps/usgs-mrms/`, which 404s when the app is served
at `/`. The Dockerfile rewrites that prefix to `/` in the installed package (public
JS, templates, and controllers) after install, and guards that none of those trees
still carry it.

## Env driven S3

S3 access is env driven and already implemented in the app (it mirrors the
`fimserve_viewer` pattern): reads from the private `ciroh-portal-assets/usgs-mrms`
prefix via IRSA, reads public NOAA MRMS anonymously, and writes results through the
Django `default_storage` (the app's S3, provided by `s3Static` plus the
`ciroh-portal` service account). The env vars set in `values-prod.yaml` are:

* `USGS_MRMS_S3_BUCKET=ciroh-portal-assets`
* `USGS_MRMS_S3_PREFIX=usgs-mrms`
* `USGS_MRMS_S3_REGION=us-east-1`
* `HYDRO_HISTORY_S3_PREFIX=experiments/hydro_history_3mm_all_stage`
* `USGS_MRMS_WORKDIR=/home/tethys/persist/usgs-mrms`

## Persistent store

The app declares one required persistent store, `jobs_db` (background flood-alert
job records shared across replicas). The `tethys-app` chart provision job runs
migrate, services, static, and syncstores, so it provisions `jobs_db` on first
deploy. See the runtime notes below on the `CREATEDB` requirement.

## Deploy (prod)

USGS-MRMS deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install usgs-mrms oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/usgs-mrms/values-prod.yaml
```

Create the `tethys_platform_usgs_mrms` database once, owned by `tethys_default`,
before the first deploy. Apply `ingress.yaml` once to route
`usgs-mrms.tethys.ciroh.org` on the shared `ciroh-apps` ALB to the KEDA
interceptor; the wildcard cert already covers the subdomain.

## Portal sign in (one time)

Register USGS-MRMS as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://usgs-mrms.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`USGS_MRMS_OIDC_CLIENT_ID` and `USGS_MRMS_OIDC_CLIENT_SECRET`.

## Runtime notes / remaining work

This is a first pass overlay. The image build and single app wiring are handled
here, but the following runtime items are unverified and need a first deploy to
confirm.

* Heavy in process compute. The app runs its own `ThreadPoolExecutor` job manager
  plus a `ProcessPoolExecutor`, decodes MRMS grib through GDAL, and fetches live
  NOAA data in the web pod. This is the same shape as the fimserve OOM and probe
  incident: long jobs can OOM kill the pod and starve the liveness and readiness
  probes, and they fight KEDA scale to zero because scale down can cut a job off.
  The pod is given generous memory (2Gi request, 8Gi limit) as a first guard. If it
  still misbehaves, mirror the fimserve PR #41 mitigations (probe tuning, memory
  headroom, resilient polling) or offload execution off the web pod.
* `jobs_db` provisioning. The chart provision job runs syncstores, but the store
  database is created by the app under `tethys_default`. Confirm `tethys_default`
  has `CREATEDB` on the RDS instance, or pre create the `jobs_db` store database;
  without it syncstores fails silently and flood-alert jobs break.
* Data staging. Confirm the private data the app reads is actually staged at
  `ciroh-portal-assets/usgs-mrms` (and the hydro history under
  `experiments/hydro_history_3mm_all_stage`) before first use.
* `USGS_API_KEY`. The events package reads `USGS_API_KEY` for USGS fetches. If the
  live USGS calls require it, inject it as a secret env var (add it to
  `ciroh-portal-secrets` and reference it under `secrets.secretEnv`).
