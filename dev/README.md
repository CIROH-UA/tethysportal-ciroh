# `dev/` — local-dev + test tools

The DB scripts here are **for local development only** (the `docker-compose.dev.yml` stack) — **not**
baked into the portal image and **never** run by the chart. The smoke test is the exception: CI runs
it against the built image, and you can run it locally too.

- **`bootstrap-database.sh`** — creates the DB roles (`tethys_default`, least-privilege `tethys_app`)
  + core databases against the throwaway compose/k3d Postgres. It stands in for the DBA, which a dev
  Postgres doesn't have. On **RDS this is DBA work** — see README §2.5 (this script is the reference).
- **`portal-seed.sh`** — one-time seed of a fresh dev portal: persistent-store service + store links +
  `syncstores`, branding, proxy apps, app settings. In **prod** the provision Job does link + syncstores.
- **`smoke_portal.py`** — checks what the portal image ships: the CIROH modules its settings name
  (`portal_oidc`, `portal_storage`), the theme extension, the HydroShare login backend, and
  `manage.py check`. The portal has no apps installed (each app is its own image, tested by
  `build_push_app_images`). CI runs it after the Grype scan and **blocks the push/deploy** on any
  failure. Run it yourself against a locally built image before deploying it:

  ```bash
  docker build -t ciroh-portal:local .
  docker run --rm \
    -e DJANGO_SETTINGS_MODULE=tethys_portal.settings -e TETHYS_SECRET_KEY=ci-smoke \
    -v "$PWD/dev/smoke_portal.py:/tmp/smoke_portal.py:ro" \
    ciroh-portal:local \
    /opt/conda/envs/tethys/bin/python /tmp/smoke_portal.py
  ```

  A clean run prints `PASS` per check and exits 0; any `FAIL` exits non-zero.

The app/CI only ever manage two DB things, as the least-privilege `tethys_app` role: `tethys db migrate`
and `tethys syncstores`. Everything else (roles, databases, ownership) is DBA work on the RDS instance.
