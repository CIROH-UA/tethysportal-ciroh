# `dev/` — local-development-only tools

Scripts here are **for local development only** (the `docker-compose.dev.yml` stack). They are
**not** baked into the portal image and are **never** run by the chart or CI.

- **`bootstrap-database.sh`** — creates the DB roles (`tethys_default`, least-privilege `tethys_app`)
  + core databases against the throwaway compose/k3d Postgres. It stands in for the DBA, which a dev
  Postgres doesn't have. On **RDS this is DBA work** — see README §2.5 (this script is the reference).
- **`portal-seed.sh`** — one-time seed of a fresh dev portal: persistent-store service + store links +
  `syncstores`, branding, proxy apps, app settings. In **prod** the provision Job does link + syncstores.

The app/CI only ever manage two DB things, as the least-privilege `tethys_app` role: `tethys db migrate`
and `tethys syncstores`. Everything else (roles, databases, ownership) is DBA work on the RDS instance.
