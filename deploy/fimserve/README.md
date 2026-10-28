# FIMserve standalone deploy

Runs the FIMserve Viewer as its own Tethys app on `ciroh-portal-prod`, separate
from the multi-app portal, mirroring the fimeval setup. The app serves at
`fimserve.tethys.ciroh.org` and offloads flood-map generation to a scale-to-zero
Dask cluster (dask-kubernetes operator), so heavy HAND compute never runs on the
web pod.

Pieces:

- Image: built from `deploy/fimserve/Dockerfile` (CIROH Tethys base) with the
  app from the `apps/fimserv-viewer` submodule. CI builds it and pushes
  `awiciroh/tethysapp-fimserve`, like the other apps.
- Chart: `deploy/fimserve/chart` (tethys-app subchart plus the Dask cluster).
  The Dask worker runs this same image and bootstraps Django with a `--preload`
  so it reaches `jobs_db` and S3 exactly as the web pod does.
- Values: `deploy/fimserve/values-prod.yaml`.
- Ingress: `deploy/fimserve/ingress.yaml` (`fimserve.tethys.ciroh.org`, KEDA
  HTTP interceptor).

## App source

The app lives in `Aquaveo/fimserv-viewer` (it moved from the archived
`Aquaveo/tethysapp-fimserve_viewer`), checked out as the `apps/fimserv-viewer`
submodule. The Dask offload (`dask_worker.py`, `execution.py`, `scheduler.py`,
`submitters.py`) is on its `feat/dask-offload` branch until that merges to
`main`; the submodule tracks that branch (switch `branch` in `.gitmodules` to
`main` once it merges). Building source without the offload needs
`--build-arg DASK_OFFLOAD=false` and a deploy with `--set dask.enabled=false`;
jobs then run in a thread on the web pod.

## One-time prerequisites (admin)

1. Database: create `tethys_platform_fimserve` on the shared RDS.
   ```
   psql -h ciroh-portal-db.cfmp1axs2tbt.us-east-1.rds.amazonaws.com -U tethys_super \
     -c "CREATE DATABASE tethys_platform_fimserve OWNER tethys_default;"
   ```
2. OIDC client: register a portal OIDC client for `https://fimserve.tethys.ciroh.org`,
   and add `FIMSERVE_OIDC_CLIENT_ID` and `FIMSERVE_OIDC_CLIENT_SECRET` to the
   `ciroh-portal-secrets` secret.
3. DNS/TLS: none. `fimserve.tethys.ciroh.org` is covered by the existing
   `*.tethys.ciroh.org` record and wildcard ACM cert on the shared `ciroh-apps` ALB.

## Build the image

CI (`build_push_app_images`) builds and tests the image when `deploy/fimserve/`
or the submodule changes, and pushes `awiciroh/tethysapp-fimserve:<portal sha>`.
To ship app changes, bump the submodule in a portal PR:

```
git submodule update --init apps/fimserv-viewer
git submodule update --remote apps/fimserv-viewer   # tip of the tracked branch
git add apps/fimserv-viewer && git commit -m "Bump FIMserve"
```

To build locally, from this repo with the submodule checked out:

```
# tests (unittest for tests/, tethys manage test for the app package)
docker build -f deploy/fimserve/Dockerfile --target test -t fimserve:test .
docker run --rm fimserve:test

# local image only; deployed images come from CI (awiciroh/tethysapp-fimserve)
docker buildx build --platform linux/amd64 -f deploy/fimserve/Dockerfile \
  -t fimserve:local --load .
```

## Deploy

```
helm dependency build deploy/fimserve/chart
helm upgrade --install fimserve deploy/fimserve/chart \
  -f deploy/fimserve/values-prod.yaml --namespace cirohportal \
  --kube-context arn:aws:eks:us-east-1:456531024327:cluster/ciroh-portal-prod
kubectl apply -f deploy/fimserve/ingress.yaml
```

After a change to the Dask cluster's spec (image, resources, env), recreate the
cluster. The Dask operator applies only worker-count changes to a running
cluster, so without this the workers keep the old app code and jobs from the new
web pod fail on them. Deploys through `deploy_apps` do this by themselves; after a
`helm upgrade` by hand, do it yourself. It interrupts running jobs, so do it when
none are running:

```
kubectl -n cirohportal delete daskcluster fimserve-dask
helm upgrade fimserve deploy/fimserve/chart -n cirohportal -f deploy/fimserve/values-prod.yaml
kubectl -n cirohportal get deploy | grep fimserve-dask   # same image as the web pod
```

## Post-deploy config (admin, once)

The standalone DB starts empty, so configure these in the app admin, then the
first generation works end to end:

1. Persistent store `jobs_db`: confirm the provision job created it
   (`tethys syncstores`); if not, run syncstores for the app.
2. App setting `s3_bucket` (and any custom settings): set to `ciroh-portal-assets`.
3. Dask scheduler: create a Tethys `DaskScheduler` named `fimserve_dask`, host
   `tcp://fimserve-dask-scheduler.cirohportal.svc.cluster.local:8786`, timeout
   `60` (never 0), then assign it to the app `dask_primary` scheduler setting.

Until `dask_primary` is assigned the app runs generation in-thread on the web
pod (fallback). Assign the scheduler so it offloads to the Dask workers.

## Verify

Submit a generation and watch a worker scale `0 -> 1`, the COG land in S3, the
job row finish, and the worker scale back to `0`:

```
kubectl -n cirohportal get daskcluster,daskautoscaler fimserve-dask
kubectl -n cirohportal get pods -l dask.org/cluster-name=fimserve-dask -w
```
