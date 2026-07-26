#!/usr/bin/env bash
set -euo pipefail

# One-time database bootstrap for the CIROH portal. Idempotent: safe to re-run.
#
# LOCAL DEV convenience: the compose/k3d stack has no DBA, so this creates the roles
# and core databases against the throwaway Postgres. On PROD (RDS) these are privileged,
# admin-side tasks the DBA runs directly on the instance -- see README §2.5 (this script
# is the reference for those steps). The chart/CI never run it.
#
# Creates:
#   - the application role (owns the portal core DB: tethys_platform)
#   - the least-privilege STORE role (LOGIN + CREATEDB, NOT superuser): the
#     persistent-store service connects as this role, so app-store creation/sync
#     via `tethys syncstores` never runs as a superuser (workshop Option B, §9-12)
#   - a membership grant so the admin can create/re-own objects for both roles
#   - a landing database named after the admin AND one named after the store role
#     (Tethys' store handlers connect with no dbname; PostgreSQL defaults it to the
#     connecting username, so syncstores' CREATE DATABASE needs a same-named DB)
#   - tethys_platform (portal core, owned by the app role)
#   - tethysdash_primary_db (tethysdash store, owned by the STORE role)
#
# App stores added later (e.g. fimserve_viewer jobs_db) are created by
# `tethys syncstores` as the store role and do NOT belong here. Re-owning EXISTING
# superuser-owned stores onto the store role is a DBA task -- see README §2.5.
#
# Required env:
#   DB_HOST            database server hostname
#   ADMIN_USER         admin/master role name (e.g. tethys_super)
#   PGPASSWORD         admin password (read by psql)
#   APP_PASSWORD       password for the application role
#   STORE_PASSWORD     password for the least-privilege store role
# Optional env:
#   DB_PORT            default 5432
#   APP_USER           default tethys_default
#   STORE_USER         default tethys_app

: "${DB_HOST:?}" "${ADMIN_USER:?}" "${PGPASSWORD:?}" "${APP_PASSWORD:?}" "${STORE_PASSWORD:?}"
DB_PORT="${DB_PORT:-5432}"
APP_USER="${APP_USER:-tethys_default}"
STORE_USER="${STORE_USER:-tethys_app}"

psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres \
  -v app_user="$APP_USER" -v app_pw="$APP_PASSWORD" \
  -v store_user="$STORE_USER" -v store_pw="$STORE_PASSWORD" <<'SQL'
-- application role (portal core DB owner)
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_pw')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_user')\gexec
SELECT format('GRANT %I TO %I', :'app_user', CURRENT_USER)
WHERE CURRENT_USER <> :'app_user'\gexec

-- least-privilege store role: LOGIN + CREATEDB, NOT superuser (workshop §9-12)
SELECT format('CREATE ROLE %I LOGIN CREATEDB PASSWORD %L', :'store_user', :'store_pw')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'store_user')\gexec
SELECT format('ALTER ROLE %I CREATEDB', :'store_user')\gexec
SELECT format('GRANT %I TO %I', :'store_user', CURRENT_USER)
WHERE CURRENT_USER <> :'store_user'\gexec

-- landing DBs (§12): connections with no dbname default to the connecting username
SELECT format('CREATE DATABASE %I OWNER %I', CURRENT_USER, CURRENT_USER)
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = CURRENT_USER::text)\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'store_user', :'store_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'store_user'::text)\gexec

-- portal core (app role) + tethysdash store (store role)
SELECT format('CREATE DATABASE tethys_platform OWNER %I', :'app_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tethys_platform')\gexec
SELECT format('CREATE DATABASE tethysdash_primary_db OWNER %I', :'store_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tethysdash_primary_db')\gexec
SQL

echo "Database bootstrap complete on ${DB_HOST}:${DB_PORT} (app=${APP_USER}, store=${STORE_USER})"
