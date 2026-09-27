#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
case ${1:-} in
    -h|--help)
        echo 'Usage: cleanup.sh [--purge-data]'
        echo 'Default removes this Compose stack, preserving DB volume. --purge-data permanently deletes its database volume.'
        exit 0 ;;
    ''|--purge-data) ;;
    *) die 'Unknown argument. Use --help.' ;;
esac
[[ $# -le 1 ]] || die 'Too many arguments.'
preflight
require_env
if [[ ${1:-} == --purge-data ]]; then
    printf 'Deleting the PostgreSQL volume for this Compose project permanently.\n' >&2
    compose down --volumes
else
    compose down
    printf 'Database volume preserved; redeploy reuses it. Playground expiry may still remove it.\n'
fi
