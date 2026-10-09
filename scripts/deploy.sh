#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
case ${1:-} in
    -h|--help) echo 'Usage: deploy.sh | Setup, build, start, wait. Verification is a separate command.'; exit 0 ;;
    '') ;;
    *) die 'Unknown argument. Use --help.' ;;
esac
[[ $# -le 1 ]] || die 'Too many arguments.'
"$ROOT/scripts/setup-env.sh"
"$ROOT/scripts/build.sh"
"$ROOT/scripts/run-local.sh"
