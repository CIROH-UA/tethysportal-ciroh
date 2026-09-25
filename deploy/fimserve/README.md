# FIMserve standalone deploy

Runs the FIMserve Viewer as its own Tethys app on `ciroh-portal-prod`, separate
from the multi-app portal, mirroring the fimeval setup. The app serves at
`fimserve.tethys.ciroh.org` and offloads flood-map generation to a scale-to-zero
Dask cluster (dask-kubernetes operator), so heavy HAND compute never runs on the
web pod.

Pieces:

- Image: built from the app repo's own `Dockerfile`
  (`Aquaveo/tethysapp-fimserve_viewer`, CIROH Tethys base) and pushed as
  `awiciroh/tethysapp-fimserve`, the same way fimeval's image is built.
- Chart: the wrapper chart lives in the app repo at
  `apps/tethysapp-fimserve_viewer/deploy/chart` (tethys-app subchart plus the
  Dask cluster). The Dask worker runs this same image and bootstraps Django with
  a `--preload` so it reaches `jobs_db` and S3 exactly as the web pod does.
- Values: `deploy/fimserve/values-prod.yaml`.
- Ingress: `deploy/fimserve/ingress.yaml` (`fimserve.tethys.ciroh.org`, KEDA
  HTTP interceptor).

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

From the app repo (`Aquaveo/tethysapp-fimserve_viewer`, currently on
`feat/dask-offload` until the offload code merges), build and push:

```
docker buildx build --platform linux/amd64 \
  -t awiciroh/tethysapp-fimserve:latest --push .
```

## Deploy

```
helm dependency build apps/tethysapp-fimserve_viewer/deploy/chart
helm upgrade --install fimserve apps/tethysapp-fimserve_viewer/deploy/chart \
  -f deploy/fimserve/values-prod.yaml --namespace cirohportal \
  --kube-context arn:aws:eks:us-east-1:456531024327:cluster/ciroh-portal-prod
kubectl apply -f deploy/fimserve/ingress.yaml
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
