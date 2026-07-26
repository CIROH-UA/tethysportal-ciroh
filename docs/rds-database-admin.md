# CIROH portal — RDS database administration (DBA runbook)

These are the **privileged, one-time database tasks** — creating roles, databases, ownership, and
extensions. They belong to the **database administrator, run directly against the RDS instance**, not
to the app or CI.

The app/CI only ever does two DB things, and never as a superuser:

- `tethys db migrate` — schema migrations (Tethys core + each app)
- `tethys syncstores` — create/sync each app's persistent store

both connecting as the least-privilege **`tethys_app`** role the DBA provisions below.

> For **local dev**, `scripts/bootstrap-database.sh` automates the equivalent of §1 against the
> throwaway compose/k3d Postgres (dev has no DBA). It is a dev convenience + a reference for these
> steps — it is **not** run by the chart or CI against RDS.

---

## 1. Roles, databases, ownership (fresh RDS — once)

Run as the RDS master user:

```sql
-- application role: owns the portal core DB (tethys_platform)
CREATE ROLE tethys_default LOGIN PASSWORD '<app_pw>';

-- least-privilege STORE role: owns app stores. LOGIN + CREATEDB, NOT superuser.
CREATE ROLE tethys_app LOGIN CREATEDB PASSWORD '<store_pw>';

-- let the master create/own objects for both roles
GRANT tethys_default TO CURRENT_USER;
GRANT tethys_app     TO CURRENT_USER;

-- landing DB: Tethys' store handlers connect with no dbname, and libpq defaults it to
-- the connecting username, so syncstores' CREATE DATABASE needs a same-named DB to land in.
CREATE DATABASE tethys_app OWNER tethys_app;

-- core databases
CREATE DATABASE tethys_platform       OWNER tethys_default;
CREATE DATABASE tethysdash_primary_db OWNER tethys_app;
```

## 2. Migrate EXISTING superuser-owned stores to `tethys_app` (upgrade — once)

Stores created under the old (superuser) model are owned by the master user. Re-own them so the
store service can connect as `tethys_app`. First the databases:

```sql
ALTER DATABASE tethysdash_primary_db   OWNER TO tethys_app;
ALTER DATABASE fimserve_viewer_jobs_db OWNER TO tethys_app;
```

Then, connected to **each** store DB, re-own its objects. `REASSIGN OWNED` refuses objects owned by a
superuser ("required by the database system"), and `ALTER DATABASE OWNER` alone only grants schema
access for *new* objects — so re-own per object:

```sql
\c tethysdash_primary_db
SELECT format('ALTER TABLE %I.%I OWNER TO tethys_app;', schemaname, tablename)
  FROM pg_tables    WHERE schemaname NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT format('ALTER SEQUENCE %I.%I OWNER TO tethys_app;', schemaname, sequencename)
  FROM pg_sequences WHERE schemaname NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT format('ALTER VIEW %I.%I OWNER TO tethys_app;', schemaname, viewname)
  FROM pg_views     WHERE schemaname NOT IN ('pg_catalog','information_schema')
\gexec
```

Repeat for `\c fimserve_viewer_jobs_db` (and any other existing store).

## 3. Point the store service at `tethys_app`

Update the **`TETHYS_PS_CONNECTION`** secret to the `tethys_app` credentials (was the superuser), then
redeploy. The provision Job's `tethys syncstores` now runs as `tethys_app` against the re-owned stores.
Backward-compatible until this step — the service keeps using whatever `TETHYS_PS_CONNECTION` holds.

---

## Notes

- CIROH's stores are **non-spatial**, so `tethys_app` (no superuser) is sufficient. A spatial store
  would need `CREATE EXTENSION postgis` (superuser) or the extension pre-created by the DBA.
- The whole flow was rehearsed on k3d (2026-07-25): a non-super `tethys_app` + landing DB creates,
  owns, and initializes a store via the real `tethys syncstores`, and the per-object re-ownership lets
  it manage migrated stores.
