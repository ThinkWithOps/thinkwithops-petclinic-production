#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
case ${1:-} in
    -h|--help) echo 'Usage: setup-env.sh | Check Docker/Compose/Python/curl/Git and prepare a private .env. No containers started.'; exit 0 ;;
    '') ;;
    *) die 'Unknown argument. Use --help.' ;;
esac
[[ $# -le 1 ]] || die 'Too many arguments.'
preflight
need curl
need git
docker buildx version >/dev/null 2>&1 || die 'Docker Buildx plugin required for BuildKit cache mounts.'
prepare_env
require_env
printf 'Setup ready. Set BIND_ADDRESS=0.0.0.0 in %s if you will open the app from another machine.\n' "$ENV_FILE"
printf 'Deploy: ./scripts/deploy.sh\nVerify: ./scripts/verify.sh\nCleanup: ./scripts/cleanup.sh\n'
