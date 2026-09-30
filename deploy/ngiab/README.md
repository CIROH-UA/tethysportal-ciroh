# NGIAB Visualizer standalone deploy

Runs the NGIAB Visualizer as its own Tethys app on `ciroh-portal-prod`, serving at
`ngiab.tethys.ciroh.org`. It deploys the upstream `tethys-app` chart directly (no
Dask, no wrapper chart); the only per-app artifacts are this overlay plus the app
image.

Pieces:

- Image: `deploy/ngiab/Dockerfile` builds `awiciroh/tethysapp-ngiab` on the CIROH
  Tethys base, via `.github/workflows/build_and_push_ngiab_image.yml`. It bakes the
  DuckDB `httpfs`+`aws` extensions into `/opt/duckdb_extensions` and sets
  `DUCKDB_HOME`, since the app loads them at runtime with autoinstall/autoload off.
- Values: `deploy/ngiab/values-prod.yaml`.
- Ingress: `deploy/ngiab/ingress.yaml`.

## One-time prerequisites (admin)

1. Database: create `tethys_platform_ngiab` on the shared RDS, owned by `tethys_default`.
2. OIDC client: register a portal OIDC client for `https://ngiab.tethys.ciroh.org`
   with redirect URI `https://ngiab.tethys.ciroh.org/oauth2/complete/tethys_portal/`,
   and add `NGIAB_OIDC_CLIENT_ID` / `NGIAB_OIDC_CLIENT_SECRET` to `ciroh-portal-secrets`.
3. DNS/TLS: none. `ngiab.tethys.ciroh.org` is covered by the existing
   `*.tethys.ciroh.org` record and wildcard ACM cert on the shared `ciroh-apps` ALB.

## Browser uploads to S3

NGIAB uploads model runs directly to S3 from the browser. The `default` storage is
S3 with SigV4 (from the tethys-app chart), and uploads reuse the shared
`ciroh-portal-assets` bucket, whose CORS is already configured for the portal's
NGIAB. `CLIENT_MAX_BODY_SIZE` is raised to 1024M for large uploads.

## Deploy

```
helm upgrade --install ngiab oci://ghcr.io/aquaveo/charts/tethys-app \
  -f deploy/ngiab/values-prod.yaml --namespace cirohportal \
  --kube-context arn:aws:eks:us-east-1:456531024327:cluster/ciroh-portal-prod
kubectl apply -f deploy/ngiab/ingress.yaml
```
