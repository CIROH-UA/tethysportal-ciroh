# SWEML on the CIROH cluster

The Snow Water Equivalent Machine Learning app (SWEML) runs as a standalone single
app Tethys portal, decoupled from the main CIROH portal image. The app source is
the `apps/tethysapp-sweml` submodule (`Aquaveo/tethysapp-sweml`, branch `main`);
this directory holds the CIROH deploy artifacts.

SWEML is a server rendered MapLayout app. Its model outputs are precomputed, so it
runs no in process ML, needs no custom settings, no persistent store, and no Dask.
That makes it simple: it deploys the upstream `tethys-app` chart directly, with no
wrapper chart.

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives SWEML its own `tethys_platform_sweml` database
on the same RDS instance. Unified identity comes from signing in through the CIROH
portal, not a shared database.

## Image

CI builds the app on the CIROH Tethys base and publishes `awiciroh/tethysapp-sweml`.
The workflow `.github/workflows/build_and_push_sweml_image.yml` runs on any push or
pull request that touches `deploy/sweml/` or the app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image. The image installs GDAL because geopandas needs it. The
app's runtime dependencies live in `deploy/sweml/requirements.txt`.

## Deploy (prod)

SWEML deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install sweml oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/sweml/values-prod.yaml
```

Create the `tethys_platform_sweml` database once, owned by `tethys_default`, before
the first deploy. Apply `ingress.yaml` once to route `sweml.tethys.ciroh.org` on the
shared `ciroh-apps` ALB to the KEDA interceptor, and add the matching DNS CNAME
(the wildcard cert already covers the subdomain).

## Portal sign in (one time)

Register SWEML as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://sweml.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`SWEML_OIDC_CLIENT_ID` and `SWEML_OIDC_CLIENT_SECRET`.

## Cross-account data access (deploy prerequisite)

SWEML reads its data from the private bucket `national-snow-model`, which lives in a
different AWS account (858933856877). This is independent of the app's own
`s3Static` and media bucket and does not use Django `default_storage`; the app opens
its own boto3 session.

By default the app STS assumes `arn:aws:iam::858933856877:role/ciroh-portal-s3-reader`
to read that bucket (the role ARN and an optional ExternalId are overridable via the
env vars `SWEML_S3_READER_ROLE_ARN` and `SWEML_S3_READER_EXTERNAL_ID`, the former
already set in `values-prod.yaml`). For this to work, two IAM changes must be made
in coordination with the data owner account before the map will have data:

1. The prod IRSA role behind the `ciroh-portal` service account must be allowed to
   `sts:AssumeRole` on `arn:aws:iam::858933856877:role/ciroh-portal-s3-reader`.
2. That role's trust policy in account 858933856877 must trust the app's IRSA
   principal (and any configured ExternalId).

Alternatively, inject static credentials as secret env `SWEML_AWS_ACCESS_KEY_ID`
and `SWEML_AWS_SECRET_ACCESS_KEY` instead of the assume role path.

This IAM setup is outside the standard `s3Static` and media IRSA and must be
arranged before the map can load data.
