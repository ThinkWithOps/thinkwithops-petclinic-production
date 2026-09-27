#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
case ${1:-} in
    -h|--help) echo 'Usage: static-check.sh | Bash syntax, ShellCheck, Compose model, XML and policy checks. No Docker daemon or runtime required.'; exit 0 ;;
    '') ;;
    *) echo 'Unknown argument. Use --help.' >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
cd "$root"
for tool in bash shellcheck python3 docker; do
    command -v "$tool" >/dev/null || { echo "Missing static-check tool: $tool" >&2; exit 1; }
done
for script in scripts/*.sh scripts/lib/*.sh docker/postgres/*.sh; do bash -n "$script"; done
sh -n docker/nginx/start.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh docker/postgres/*.sh docker/nginx/start.sh
docker compose --env-file docker/.env.example -f docker/compose.yaml config --quiet
docker compose --env-file docker/.env.example -f docker/compose.yaml config --format json | python3 scripts/check-static.py
printf 'PASS: static checks only. Runtime verification remains separate.\n'
