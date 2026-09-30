# NRDS standalone deploy

Runs the NRDS client as its own Tethys app on `ciroh-portal-prod`, serving at
`nrds.tethys.ciroh.org`, via the upstream `tethys-app` chart (no Dask, no wrapper).

Pieces:

- Image: `deploy/nrds/Dockerfile` builds `awiciroh/tethysapp-nrds` on the CIROH
  Tethys base, via `.github/workflows/build_and_push_nrds_image.yml`. It runs
  `scripts/build_slim_index.py` before install and asserts the slim hydrofabric
  parquet (>30MB) is packaged, so the index is served rather than 403ing from S3.
- Values: `deploy/nrds/values-prod.yaml`.
- Ingress: `deploy/nrds/ingress.yaml`.

## One-time prerequisites (admin)

1. Database: create `tethys_platform_nrds` on the shared RDS, owned by `tethys_default`.
2. OIDC client: register a portal OIDC client for `https://nrds.tethys.ciroh.org`
   with redirect URI `https://nrds.tethys.ciroh.org/oauth2/complete/tethys_portal/`,
   and add `NRDS_OIDC_CLIENT_ID` / `NRDS_OIDC_CLIENT_SECRET` to `ciroh-portal-secrets`.
3. DNS/TLS: none. `nrds.tethys.ciroh.org` is covered by the wildcard record + cert.

## Deploy

```
helm upgrade --install nrds oci://ghcr.io/aquaveo/charts/tethys-app --version 0.1.5 \
  -f deploy/nrds/values-prod.yaml --namespace cirohportal \
  --kube-context arn:aws:eks:us-east-1:456531024327:cluster/ciroh-portal-prod
kubectl apply -f deploy/nrds/ingress.yaml
```
