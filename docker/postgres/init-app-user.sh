#!/usr/bin/env bash
# Entrypoint hook, not a user CLI. Runs on a newly initialized PostgreSQL volume.
set -euo pipefail
: "${APP_DB_USER:?APP_DB_USER required}" "${APP_DB_PASSWORD:?APP_DB_PASSWORD required}"
: "${POSTGRES_USER:?POSTGRES_USER required}" "${POSTGRES_DB:?POSTGRES_DB required}"
command -v psql >/dev/null
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --no-psqlrc --set ON_ERROR_STOP=1 <<'SQL'
\getenv app_user APP_DB_USER
\getenv app_password APP_DB_PASSWORD
SELECT format('CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user') \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'app_user') \gexec
SELECT format('GRANT USAGE, CREATE ON SCHEMA public TO %I', :'app_user') \gexec
SQL
