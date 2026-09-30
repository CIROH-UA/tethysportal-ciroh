# TethysDash on the CIROH cluster

TethysDash runs as a standalone single app Tethys portal, decoupled from the main
CIROH portal image. The app source is the `apps/tethysapp-tethys_dash` submodule
(`tethysplatform/tethysapp-tethys_dash`); this directory holds the CIROH deploy
artifacts.

This is the most involved standalone app so far. It is a React/webpack SPA whose
API and WebSocket URLs are baked at build time, it needs a PostgreSQL persistent
store managed by Alembic, and it uses Django Channels over Redis for live chat and
progress notifications. Treat this overlay as a first pass. The build time pieces
are handled here; several runtime behaviours still need to be confirmed on the
cluster (see "Remaining and unverified work").

## Why its own database

The Tethys app registry is global to a database, so a standalone app that shares
the portal's `tethys_platform` database registers itself as a real app and crashes
the portal. `values-prod.yaml` gives TethysDash its own `tethys_platform_tethysdash`
database on the same RDS instance. Unified identity comes from signing in through
the CIROH portal (see `../oidc`), not a shared database.

## Image

CI builds the app (React webpack build, then the Tethys app) on the CIROH Tethys
base and publishes `awiciroh/tethysapp-tethysdash`. The workflow
`.github/workflows/build_and_push_tethysdash_image.yml` runs on any push or pull
request that touches `deploy/tethysdash/` or the app submodule, and on demand via
`workflow_dispatch` (where the `ciroh-tethys` base image can be pinned). It tags
`:<sha>` (immutable) on every run, and also moves `:latest` on push and dispatch.

The Dockerfile builds on `awiciroh/ciroh-tethys:builder_<sha>`, so the portal OIDC
login backend, the leading slash S3 static fix, and the branded login templates
ship inside the image.

### Single app build environment

`dotenv-webpack` bakes values into the SPA at build time by reading
`reactapp/config/production.env`, which the app repo gitignores. The Dockerfile
copies `deploy/tethysdash/production.env` into that path before `npm run build`, so
the bundle is built for single app mode served at the site root:

```
TETHYS_APP_ROOT_URL = "/"
TETHYS_PREFIX_URL    = ""
TETHYS_APP_ID        = tethysdash
REDIS_WS_URL         = "wss://tethysdash.tethys.ciroh.org/visualizations/notifications/ws/"
```

The frontend uses `TETHYS_APP_ROOT_URL` as the base for every REST call and uses
`REDIS_WS_URL` verbatim to open the chat/notifications socket. Live WebSocket
features turn themselves off cleanly when `REDIS_WS_URL` is empty, so blanking it in
`production.env` is the switch to ship without live chat.

The production build bakes a same origin `/static/tethysdash/frontend/` publicPath
into the webpack runtime. Because static is served from S3 under `s3Static`, the
Dockerfile rewrites `/static/tethysdash/` to the S3 static base in the built JS and
CSS, the same way the FIMbench image does, so lazy loaded chunks and assets resolve.

## Redis

Django Channels and the Django cache both use the in cluster Valkey service
`ciroh-valkey:6379` (namespace `cirohportal`); no new Redis is provisioned.
`values-prod.yaml` sets `CHANNEL_LAYERS` to `channels_redis` on database 0 and
`CACHES` to `django_redis` on database 1. Channels carries the live chat and plugin
progress messages; the cache backs the per session chat rate limit.

## Persistent store

The app declares one required persistent store, `primary_db`, whose initializer
runs Alembic migrations to build the dashboard, grid item, permission, and message
tables. The `tethys-app` chart provision job runs `syncstores`, which invokes that
initializer, so the schema is created on first deploy once the database exists and
is reachable.

Create the `tethys_platform_tethysdash` database once, owned by `tethys_default`,
before the first deploy.

`geoalchemy2` is a declared dependency, but the current models and migrations do not
define any geometry columns, so PostGIS is probably not required by today's schema.
If a migration ever fails referencing a geometry type, enable the extension once on
the store database:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

## Deploy (prod)

TethysDash deploys the upstream `tethys-app` chart directly:

```bash
helm upgrade --install tethysdash oci://ghcr.io/aquaveo/charts/tethys-app \
  --version 0.1.5 -n cirohportal -f deploy/tethysdash/values-prod.yaml
```

Apply `ingress.yaml` once to route `tethysdash.tethys.ciroh.org` on the shared
`ciroh-apps` ALB to the KEDA interceptor. The wildcard cert already covers the
subdomain.

## Portal sign in (one time)

Register TethysDash as an OAuth2 client in the portal at
`https://tethys.ciroh.org/o/applications/register/`: client type `confidential`,
grant type `authorization-code`, redirect URI
`https://tethysdash.tethys.ciroh.org/oauth2/complete/tethys_portal/`, Algorithm
`RSA with SHA-2 256`. Store the credentials in `ciroh-portal-secrets` under
`TETHYSDASH_OIDC_CLIENT_ID` and `TETHYSDASH_OIDC_CLIENT_SECRET`.

## Remaining and unverified work

This overlay compiles and packages the app, but the following still need to be
proven on the cluster and are likely to need iteration.

1. Frontend build environment. `TETHYS_APP_ROOT_URL="/"` and `TETHYS_PREFIX_URL=""`
assume single app mode strips the app root prefix and serves the app at `/`, which
matches how FIMbench is built. Confirm the SPA loads and its REST calls resolve. If
the app is actually served under `/tethysdash/`, change those two values (and the
path segment in `REDIS_WS_URL`) accordingly and rebuild.

2. Static and chunk loading. The `/static/tethysdash/` to S3 rewrite is unverified
for this bundle. Confirm the main bundle, lazy chunks (Plotly and others), and image
assets all load without 404, and that `collectstatic` uploaded
`static/tethysdash/frontend/` to the bucket.

3. WebSocket and scale to zero. This is the highest risk item. The WS path
`/visualizations/notifications/ws/` must match the consumer route in single app mode.
The socket also has to survive the KEDA HTTP interceptor and scale to zero: live chat
and progress notifications drop on a cold start and during scale events. If live WS
must be reliable, pin a warm replica (raise the KEDA minimum, or move the app service
off scale to zero) and confirm the ALB and interceptor pass WebSocket upgrades.

4. Local filesystem media and workspace writes. Dashboard preview PNGs are written
with `shutil.copyfile` and `open()` into the app media directory, and JSON uploads are
written with `open()` into the app workspace, rather than through `default_storage`.
These writes are per pod and are not backed by S3, so previews and uploaded JSON break
across scaled or restarted pods. Dashboard data itself lives in the database and is
safe. A durable fix needs the app code switched to `default_storage`, or a shared
volume mounted for media and workspace.

5. PostGIS. Not expected to be needed by the current schema (see above), but enable
the extension if store initialization fails on a geometry type.

6. Visualization plugins. Visualizations load through `intake` entry points. Any
plugin that pulls a data source not already in the image will need its package added
to the build.

Upstream code changes (for example switching media writes to `default_storage`) target
`tethysplatform/tethysapp-tethys_dash`, not an Aquaveo fork.
