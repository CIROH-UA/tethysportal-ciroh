# Hydro Correlation Tool standalone deploy

Runs the Hydro Correlation Tool as its own Tethys app on `ciroh-portal-prod`,
serving at `hydro-correlation.tethys.ciroh.org`. It deploys the upstream
`tethys-app` chart directly (no Dask, no wrapper chart); the only per-app
artifacts are this overlay plus the app image.

Pieces:

- Image: `deploy/hydro-correlation-tool/Dockerfile` builds
  `awiciroh/tethysapp-hydro-correlation-tool` on the CIROH Tethys base, via
  `.github/workflows/build_and_push_hydro_correlation_image.yml`.
- Values: `deploy/hydro-correlation-tool/values-prod.yaml`.
- Ingress: `deploy/hydro-correlation-tool/ingress.yaml`.

## One-time prerequisites (admin)

1. Database: create `tethys_platform_hydrocorrelation` on the shared RDS,
   owned by `tethys_default`.
2. OIDC client: register a portal OIDC client for
   `https://hydro-correlation.tethys.ciroh.org` with redirect URI
   `https://hydro-correlation.tethys.ciroh.org/oauth2/complete/tethys_portal/`,
   and add `HYDRO_CORRELATION_OIDC_CLIENT_ID` / `HYDRO_CORRELATION_OIDC_CLIENT_SECRET`
   to the `ciroh-portal-secrets` secret.
3. DNS/TLS: none. `hydro-correlation.tethys.ciroh.org` is covered by the existing
   `*.tethys.ciroh.org` record and wildcard ACM cert on the shared `ciroh-apps` ALB.

## Deploy

```
helm upgrade --install hydro-correlation-tool oci://ghcr.io/aquaveo/charts/tethys-app \
  -f deploy/hydro-correlation-tool/values-prod.yaml --namespace cirohportal \
  --kube-context arn:aws:eks:us-east-1:456531024327:cluster/ciroh-portal-prod
kubectl apply -f deploy/hydro-correlation-tool/ingress.yaml
```
