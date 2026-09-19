# FIMeval on the CIROH cluster

FIMeval is a standalone Tethys app, decoupled from the portal image. Its generic
Helm chart lives in the app repo (`Aquaveo/tethysapp-fimeval-gui`, `deploy/chart`);
this directory holds only the CIROH environment overlay.

Currently deployed to **staging only** (`staging` namespace). There is no prod
FIMeval yet; when there is, add a prod overlay here.

## Install (staging)

From a checkout of the app repo (`tethysapp-fimeval-gui`):

```bash
helm dependency build deploy/chart
helm install fimeval deploy/chart \
  -n staging --create-namespace \
  -f <tethysportal-ciroh>/deploy/fimeval/values-staging.yaml
```

`values-staging.yaml` points at the `tethys_platform_staging` database (same RDS as
prod, seeded from `tethys_platform`), runs with `DEBUG` on so the dev server serves
static, uses the shared `ciroh-staging-irsa` role, namespaces S3 under
`staging/fimeval/`, and exposes no public ingress. Reach it via:

```bash
kubectl port-forward -n staging svc/fimeval 8080:8080
```

The shared staging IAM role lives at `../iam/ciroh-staging-irsa/`. Set the app's
`s3_bucket` custom setting to `ciroh-portal-assets` post-deploy (keys blank, IRSA).
