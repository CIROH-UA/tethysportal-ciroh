# FIMeval on the CIROH portal

FIMeval is a standalone Tethys app, deployed on its own subdomain on the shared
ciroh-portal ALB, decoupled from the portal image. Its generic Helm chart lives in
the app repo (`Aquaveo/tethysapp-fimeval-gui`, `deploy/chart`); this directory holds
only the CIROH environment overlay.

## Install

From a checkout of the app repo (`tethysapp-fimeval-gui`):

```bash
helm dependency build deploy/chart
helm install fimeval deploy/chart \
  -n fimeval --create-namespace \
  -f <tethysportal-ciroh>/deploy/fimeval/values.yaml
```

`values.yaml` sets the shared RDS host, the `fimeval-s3-irsa` role, the
`fimeval.tethys.ciroh.org` ingress on the `ciroh-portal` ALB group, and spot
worker placement. `iam/` holds the concrete trust and permission policies for the
`fimeval-s3-irsa` role (S3 on `ciroh-portal-assets/fimeval/*`).

## DNS and TLS

Per-app subdomains on the shared ALB need, once:

- a DNS record for the host (`fimeval.tethys.ciroh.org`, or a wildcard
  `*.tethys.ciroh.org`) pointing at the portal ALB, and
- an ACM cert covering the host (a wildcard `*.tethys.ciroh.org` covers every app).

The ALB routes by Host header, so the raw ELB name returns 404 by design.
