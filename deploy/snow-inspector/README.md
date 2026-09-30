# Snow Inspector on the CIROH cluster

Snow Inspector runs as a standalone single app Tethys portal, decoupled from the
main CIROH portal image. The app source is the `apps/snow-inspector` submodule
(`Aquaveo/snow-inspector`, branch `tethys4_upgrade`); this directory holds the
CIROH deploy artifacts.

Snow Inspector is a server rendered app (no React build). It reads snow cover
imagery from public NASA GIBS/Earthdata WMTS tiles, so it needs no data
credentials, no `s3_bucket` setting, no persistent store, and no Dask. That keeps
it simple: it deploys the upstream `tethys-app` chart directly, with no wrapper
chart.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives Snow Inspector its own
`tethys_platform_snow_inspector` database on the same RDS instance. Unified
identity comes from signing in through the CIROH portal (see `../oidc`), not a
shared database.

## Image

CI builds the app on the CIROH Tethys base and publishes
`awiciroh/tethysapp-snow-inspector`. The workflow
`.github/workflows/build_and_push_snow-inspector_image.yml` runs on any push or
pull request that touches `deploy/snow-inspector/` or the app submodule, and on
demand via `workflow_dispatch` (where the `ciroh-tethys` base image can be
pinned). It tags `:<sha>` (immutable) on every run, and also moves `:latest` on
push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image.

## Deploy (prod)

Snow Inspector deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install snow-inspector oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/snow-inspector/values-prod.yaml
```

Create the `tethys_platform_snow_inspector` database once, owned by
`tethys_default`, before the first deploy. Apply `ingress.yaml` once to route
`snow-inspector.tethys.ciroh.org` on the shared `ciroh-apps` ALB to the KEDA
interceptor, and add the matching DNS CNAME (the wildcard cert already covers the
subdomain).

## Portal sign in (one time)

Register Snow Inspector as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://snow-inspector.tethys.ciroh.org/oauth2/complete/tethys_portal/`,
Algorithm `RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets`
under `SNOW_INSPECTOR_OIDC_CLIENT_ID` and `SNOW_INSPECTOR_OIDC_CLIENT_SECRET`.

## Notes

The app's `install.yml` is broken: it lists a bogus pip dependency `see` and omits
`hs_restclient`, and its `pyproject.toml` declares no dependencies. Runtime deps
therefore come from `deploy/snow-inspector/requirements.txt`, not the app's own
metadata. `matplotlib` appears only in dead code (`fetch_modis.py`) and is not
installed.

The imagery source is public NASA GIBS/Earthdata WMTS and needs no credentials.

The "upload to HydroShare" feature depends on the HydroShare OAuth backend and a
HydroShare identity. Since SSO here is the portal OIDC rather than HydroShare, that
feature may need gating or a separate HydroShare login before it works.
