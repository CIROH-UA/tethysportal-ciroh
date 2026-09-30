# CIROH Tethys Portal, Architecture

Diagrams of the production deployment (`tethys.ciroh.org` and the per app
subdomains), generated with [`diagrams`](https://diagrams.mingrammer.com/).

The portal was split from a single monolithic image into a lean hub plus a set
of independent standalone apps. The hub serves the landing page and the app
launcher and acts as the single sign on provider. Every app now runs as its own
Tethys deployment with its own image, its own database, and its own subdomain,
and scales to zero when idle.

## Diagrams

### Infrastructure

![Infrastructure](ciroh_portal_infrastructure.png)

Runs on EKS `ciroh-portal-prod` (us-east-1) in namespace `cirohportal`:

- Ingress: a shared external ALB (`ciroh-apps`) routes `tethys.ciroh.org` to the
  hub and every `<app>.tethys.ciroh.org` to that app. Static assets go straight
  to S3 (no CloudFront; bundles are gzipped at upload).
- Hub: the `cirohportal-prod` Deployment (Tethys under uvicorn), right sized
  after the cutover, behind an HPA and a PDB. It carries no apps. It is the
  OpenID Connect provider at `/o/`, and it signs users in through HydroShare, so
  HydroShare stays the source of identity. `valkey` backs cache and channels.
- Apps: each app is a separate Deployment fronted by KEDA HTTP scale to zero, so
  a subdomain spins its pod up on the first request and back down when idle. The
  two compute apps (fimeval, fimserve) also own a Dask cluster (scheduler plus an
  autoscaled worker) that runs the heavy jobs off the web pods.
- Nodes (Karpenter): one on demand baseline node (managed node group) hosts the
  controllers and system pods; Karpenter provisions Spot elastic nodes and
  consolidates them, draining gracefully off the Spot interruption SQS queue.
- AWS state: one RDS Postgres (`ciroh-portal-db`) hosting the hub database and a
  separate `tethys_platform_<app>` database per app; S3 `ciroh-portal-assets` for
  static (gzip) and per app media under `media/<app>/`; and IRSA
  (`ciroh-portal`) for keyless S3 access.

### Sign on and app launch

![Data flow](ciroh_portal_dataflow.png)

A browser hits the hub, signs in once through the portal OIDC provider (which
delegates to HydroShare), then launches any app. Each app authenticates the same
user against the hub as an OIDC client, so one login covers the whole suite. Each
app reads its own data sources and persists to its own database:

- fimserve: HAND flood inundation; offloads jobs to Dask; reads HAND from
  `ciroh-owp-hand-fim` and streamflow from the NWM v3 retrospective (teehr).
- usgs-mrms: flood alert; reads MRMS and reference data from
  `ciroh-portal-assets` via IRSA.
- hydro-correlation-tool: USGS, NWM, and GEOGLOWS gage crosswalk; calls the USGS,
  GEOGLOWS, NWM, and MapBox APIs and caches results in its own database.
- ngiab: NextGen In A Box model run visualizer; browser uploads land directly in
  S3 (`media/ngiab_visualizer/`), and the app reads runs back from there.
- nrds: NextGen deck.gl viewer; pulls PMTiles and per VPU Arrow from
  `communityhydrofabric` and `ngen-datastream`, plus a slim search index from S3.
  Large objects use HTTP range reads, so they are left uncompressed.

## Regenerate

```bash
pip install diagrams        # also needs the graphviz `dot` binary on PATH
python docs/architecture/architecture.py
```
