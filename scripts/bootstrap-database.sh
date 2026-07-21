#!/usr/bin/env bash
set -euo pipefail

# One-time database bootstrap for the CIROH portal. Run as the database admin
# BEFORE the first deploy against a fresh PostgreSQL server (RDS, local, or the
# in-cluster dev database). Idempotent: safe to re-run.
#
# Creates:
#   - the application role (owns all portal databases)
#   - a membership grant so the admin can create objects owned by the app role
#   - a database named after the admin user (Tethys' store handlers connect
#     without a database name, and PostgreSQL defaults it to the username)
#   - tethys_platform (portal core)
#   - tethysdash_primary_db (tethysdash store, needed before its first init)
#
# App stores added later (e.g. fimserve_viewer jobs_db) are created by the
# portal init hooks via `tethys syncstores` and do NOT belong here.
#
# Required env:
#   DB_HOST            database server hostname
#   ADMIN_USER         admin/master role name (e.g. tethys_super)
#   PGPASSWORD         admin password (read by psql)
#   APP_PASSWORD       password for the application role
# Optional env:
#   DB_PORT            default 5432
#   APP_USER           default tethys_default

: "${DB_HOST:?}" "${ADMIN_USER:?}" "${PGPASSWORD:?}" "${APP_PASSWORD:?}"
DB_PORT="${DB_PORT:-5432}"
APP_USER="${APP_USER:-tethys_default}"

psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres \
  -v app_user="$APP_USER" -v app_pw="$APP_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_pw')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_user')\gexec
SELECT format('GRANT %I TO %I', :'app_user', CURRENT_USER)
WHERE CURRENT_USER <> :'app_user'\gexec
SELECT format('CREATE DATABASE %I OWNER %I', CURRENT_USER, CURRENT_USER)
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = CURRENT_USER::text)\gexec
SELECT format('CREATE DATABASE tethys_platform OWNER %I', :'app_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tethys_platform')\gexec
SELECT format('CREATE DATABASE tethysdash_primary_db OWNER %I', :'app_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tethysdash_primary_db')\gexec
SQL

echo "Database bootstrap complete on ${DB_HOST}:${DB_PORT}"
