#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
case ${1:-} in
    -h|--help) echo 'Usage: run-local.sh | Start a previously built image, wait for health, print URLs. Does not verify persistence.'; exit 0 ;;
    '') ;;
    *) die 'Unknown argument. Use --help.' ;;
esac
[[ $# -le 1 ]] || die 'Too many arguments.'
preflight
prepare_env
require_env
image=$(config_value services app image)
docker image inspect "$image" >/dev/null 2>&1 || die 'App image missing; run ./scripts/build.sh or ./scripts/deploy.sh.'
compose up --detach --no-build --wait --wait-timeout "$(wait_timeout)"
printf 'PetClinic: %s\nNginx health: %s/nginx-health\n' "$(local_url)" "$(local_url)"
printf 'On a cloud playground, open the published HTTP_PORT in its port viewer. Verify: ./scripts/verify.sh\n'
