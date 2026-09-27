#!/usr/bin/env bash
# Shared helpers, sourced by the user-facing scripts; not a standalone CLI.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT/docker/.env"}
[[ $ENV_FILE = /* ]] || ENV_FILE="$PWD/$ENV_FILE"
export ENV_FILE

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Install $1 before continuing."; }
compose() { docker compose --env-file "$ENV_FILE" -f "$ROOT/docker/compose.yaml" "$@"; }

preflight() {
    need docker
    need python3
    docker compose version >/dev/null 2>&1 || die 'Docker Compose v2+ plugin required.'
    docker info >/dev/null 2>&1 || die 'Docker daemon unavailable. Run this script in the Docker Playground.'
    [[ $(docker info --format '{{.OSType}}/{{.Architecture}}') =~ ^linux/(x86_64|amd64)$ ]] ||
        die 'Pinned Alpine Java runtime requires a Linux amd64 Docker engine.'
}

prepare_env() {
    if [[ ! -f $ENV_FILE ]]; then
        printf 'WARNING: creating private %s from docker/.env.example. Review before deployment.\n' "$ENV_FILE" >&2
        (umask 077; cp "$ROOT/docker/.env.example" "$ENV_FILE")
    fi
    python3 - "$ENV_FILE" <<'PY'
import os
import pathlib
import secrets
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
updated = text.replace('REPLACE_WITH_RANDOM_APP_PASSWORD', secrets.token_hex(32))
updated = updated.replace('REPLACE_WITH_RANDOM_ADMIN_PASSWORD', secrets.token_hex(32))
if updated != text:
    path.write_text(updated)
os.chmod(path, 0o600)
PY
}

require_env() {
    [[ -f $ENV_FILE ]] || die 'Missing .env; run ./scripts/setup-playground.sh.'
    compose config --quiet
    compose config --format json | python3 -c '
import json, re, sys
c = json.load(sys.stdin)
p = c["services"]["postgres"]["environment"]
for key in ("POSTGRES_DB", "APP_DB_USER"):
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,62}", str(p[key])):
        sys.exit(f"Invalid {key}: use a PostgreSQL identifier without punctuation.")
if p["APP_DB_USER"] == "postgres":
    sys.exit("Application role must differ from postgres administrator.")
for key in ("APP_DB_PASSWORD", "POSTGRES_PASSWORD"):
    value = str(p[key])
    if len(value) < 24 or value.startswith("REPLACE_"):
        sys.exit(f"Set a strong {key}; run setup-playground.sh for placeholder replacement.")
if p["APP_DB_PASSWORD"] == p["POSTGRES_PASSWORD"]:
    sys.exit("Use separate application and administrator passwords.")
'
}

config_value() {
    compose config --format json | python3 -c '
import json, sys
value = json.load(sys.stdin)
for key in sys.argv[1:]:
    value = value[int(key)] if isinstance(value, list) else value[key]
print(value)
' "$@"
}

wait_timeout() {
    [[ ${WAIT_TIMEOUT:-300} =~ ^[1-9][0-9]*$ ]] || die 'WAIT_TIMEOUT must be a positive integer in seconds.'
    printf '%s' "${WAIT_TIMEOUT:-300}"
}

local_url() {
    printf 'http://127.0.0.1:%s' "$(config_value services nginx ports 0 published)"
}
