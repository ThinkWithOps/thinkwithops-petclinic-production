#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
case ${1:-} in
    -h|--help)
        echo 'Usage: validate-local.sh [--smoke-only]'
        echo 'Default verifies runtime, creates a temporary owner through HTTP, recreates this Compose stack (brief outage), proves persistence, removes test owner.'
        echo '--smoke-only skips recreation and is NOT complete V1 validation. Optional PUBLIC_URL adds a check against an externally reachable URL.'
        exit 0 ;;
    ''|--smoke-only) ;;
    *) die 'Unknown argument. Use --help.' ;;
esac
[[ $# -le 1 ]] || die 'Too many arguments.'
preflight
need curl
require_env
url=$(local_url)
db=$(config_value services postgres environment POSTGRES_DB)
sql() { compose exec -T postgres psql -U postgres -d "$db" -AtX -v ON_ERROR_STOP=1 -c "$1"; }
healthy() {
    local service cid status
    for service in postgres app nginx; do
        cid=$(compose ps -q "$service")
        [[ -n $cid ]] || die "$service container missing. Deploy first."
        status=$(docker inspect --format '{{.State.Health.Status}}' "$cid")
        [[ $status == healthy ]] || die "$service health=$status"
    done
    printf 'PASS: all three containers healthy\n'
}
http_checks() {
    local path code
    curl --fail --silent --show-error --max-time 20 "$url/" | grep -q 'PetClinic' || die 'PetClinic home page missing.'
    curl --fail --silent --show-error --max-time 20 "$url/nginx-health" | grep -qx ok || die 'Nginx health failed.'
    for path in /actuator /actuator/health /actuator/env '/actuator;test/health' '/%61ctuator/health'; do
        code=$(curl --path-as-is --silent --show-error --max-time 20 --output /dev/null --write-out '%{http_code}' "$url$path")
        [[ $code == 404 ]] || die "Actuator path $path returned $code, expected 404."
    done
    printf 'PASS: application reachable; actuator paths blocked\n'
}
healthy
compose exec -T nginx nginx -t
http_checks
app_id=$(compose ps -q app)
nginx_id=$(compose ps -q nginx)
postgres_id=$(compose ps -q postgres)
docker inspect "$app_id" "$nginx_id" "$postgres_id" | python3 "$ROOT/scripts/check-runtime.py"
[[ $(compose exec -T app id -u) == 10001 ]] || die 'Unexpected app UID.'
[[ $(compose exec -T nginx id -u) == 101 ]] || die 'Unexpected Nginx UID.'
compose exec -T app wget -q -O /dev/null http://127.0.0.1:8080/actuator/health/liveness
compose exec -T app wget -q -O /dev/null http://127.0.0.1:8080/actuator/health/readiness
printf 'PASS: non-root UIDs and direct probe endpoints\n'
image_id=$(docker inspect "$app_id" --format '{{.Image}}')
docker image inspect "$image_id" --format 'Image={{.Id}} User={{.Config.User}} Bytes={{.Size}}'
docker history --no-trunc --format '{{.Size}}\t{{.CreatedBy}}' "$image_id"
bytes=$(docker image inspect "$image_id" --format '{{.Size}}')
if ((bytes >= 200000000)); then
    printf 'SIZE BUDGET EXCEEDED: %s bytes; ADR 0001 jlink follow-up required before release.\n' "$bytes" >&2
fi
if [[ -n ${PUBLIC_URL:-} ]]; then
    [[ $PUBLIC_URL =~ ^https?:// ]] || die 'PUBLIC_URL must begin with http:// or https://.'
    curl --fail --silent --show-error --location --max-time 30 "$PUBLIC_URL/" | grep -q 'PetClinic' || die 'External viewer did not return PetClinic (may require browser authentication).'
    printf 'PASS: optional external viewer smoke test\n'
fi
if [[ ${1:-} == --smoke-only ]]; then
    printf 'SMOKE ONLY: PostgreSQL write/read/persistence verification still PENDING.\n'
    exit 0
fi

marker="V1Validation$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
cleanup_probe() {
    local result=$?
    trap - EXIT
    if ! sql "DELETE FROM owners WHERE first_name='V1Probe' AND last_name='$marker';" >/dev/null; then
        printf 'Probe cleanup failed; temporary owner last_name=%s. See troubleshooting.\n' "$marker" >&2
        result=1
    fi
    exit "$result"
}
trap cleanup_probe EXIT
status=$(curl --silent --show-error --max-time 30 --output /dev/null --write-out '%{http_code}' \
    --data-urlencode firstName=V1Probe --data-urlencode "lastName=$marker" \
    --data-urlencode 'address=1 Validation Street' --data-urlencode city=Testville \
    --data-urlencode telephone=5555550100 "$url/owners/new")
[[ $status == 302 ]] || die "Create-owner POST returned $status; expected 302."
owner_id=$(sql "SELECT id FROM owners WHERE first_name='V1Probe' AND last_name='$marker';")
[[ $owner_id =~ ^[0-9]+$ ]] || die 'HTTP-created owner missing from PostgreSQL (or duplicated).'
curl --fail --silent --show-error --max-time 20 "$url/owners/$owner_id" | grep -q "$marker" || die 'App cannot read probe owner.'
role=$(config_value services app environment POSTGRES_USER)
[[ $(sql "SELECT rolsuper::text FROM pg_roles WHERE rolname='$role';") == false ]] || die 'Application database role is superuser.'
printf 'PASS: HTTP write/read matches PostgreSQL row; app role is not superuser\n'
snapshot_sql="SELECT 'owners', count(*) FROM owners UNION ALL SELECT 'pets', count(*) FROM pets UNION ALL SELECT 'visits', count(*) FROM visits UNION ALL SELECT 'vets', count(*) FROM vets UNION ALL SELECT 'specialties', count(*) FROM specialties UNION ALL SELECT 'vet_specialties', count(*) FROM vet_specialties UNION ALL SELECT 'types', count(*) FROM types ORDER BY 1;"
before=$(sql "$snapshot_sql")
printf 'Recreating this Compose project; preserving database volume. Brief outage expected.\n'
compose down
compose up --detach --no-build --wait --wait-timeout "$(wait_timeout)"
healthy
http_checks
[[ $(sql "SELECT id FROM owners WHERE first_name='V1Probe' AND last_name='$marker';") == "$owner_id" ]] || die 'Probe owner did not persist.'
[[ $(sql "$snapshot_sql") == "$before" ]] || die 'Table counts changed after restart; inspect SQL initialization (or concurrent demo traffic).'
curl --fail --silent --show-error --max-time 20 "$url/owners/$owner_id" | grep -q "$marker" || die 'Persisted owner not visible through app.'
printf 'PASS: persistence across down/up; no duplicate seed rows; app reads persisted data\n'
printf 'PASS: V1 functional runtime checks complete. Record size/history and external browser result before milestone release.\n'
