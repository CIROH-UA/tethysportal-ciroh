#!/usr/bin/env bash
set -euo pipefail

# One-time migration: move EXISTING persistent-store databases (created + owned by the
# superuser under the old model) onto the least-privilege store role, so the store
# service can connect as that role going forward. Idempotent; safe to re-run.
#
# For each store DB: ALTER DATABASE OWNER, then re-own every table/sequence/view to the
# store role with per-object ALTER — REASSIGN OWNED refuses superuser-owned objects
# ("required by the database system"), and ALTER DATABASE OWNER alone only grants schema
# access for NEW objects, not the pre-existing ones. (Rehearsed on k3d 2026-07-25.)
#
# Run as the database admin, AFTER bootstrap-database.sh has created the store role, and
# BEFORE repointing the store service (TETHYS_PS_CONNECTION) at it.
#
# Required env: DB_HOST, ADMIN_USER, PGPASSWORD ; Optional: DB_PORT, STORE_USER
# Args: store database names (default: CIROH's two)

: "${DB_HOST:?}" "${ADMIN_USER:?}" "${PGPASSWORD:?}"
DB_PORT="${DB_PORT:-5432}"
STORE_USER="${STORE_USER:-tethys_app}"
STORES=("$@"); [ ${#STORES[@]} -eq 0 ] && STORES=(tethysdash_primary_db fimserve_viewer_jobs_db)

adm() { psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" "$@"; }

for db in "${STORES[@]}"; do
  if [ -z "$(adm -d postgres -tAc "select 1 from pg_database where datname='${db}'")" ]; then
    echo "  ${db}: does not exist — skipping"; continue
  fi
  echo "==> re-owning ${db} -> ${STORE_USER}"
  adm -d postgres -c "ALTER DATABASE \"${db}\" OWNER TO \"${STORE_USER}\";"
  adm -d "$db" -tAc "
    select 'ALTER TABLE '||quote_ident(schemaname)||'.'||quote_ident(tablename)||' OWNER TO \"${STORE_USER}\";'
      from pg_tables    where schemaname not in ('pg_catalog','information_schema')
    union all
    select 'ALTER SEQUENCE '||quote_ident(schemaname)||'.'||quote_ident(sequencename)||' OWNER TO \"${STORE_USER}\";'
      from pg_sequences where schemaname not in ('pg_catalog','information_schema')
    union all
    select 'ALTER VIEW '||quote_ident(schemaname)||'.'||quote_ident(viewname)||' OWNER TO \"${STORE_USER}\";'
      from pg_views     where schemaname not in ('pg_catalog','information_schema')
  " | adm -d "$db"
  echo "    done (${db} owner now: $(adm -d postgres -tAc "select pg_get_userbyid(datdba) from pg_database where datname='${db}'"))"
done
echo "Store re-ownership complete for: ${STORES[*]}"
