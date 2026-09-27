#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"
push=false
registry=${REGISTRY:-}
while (($#)); do
    case $1 in
        --push) push=true; shift ;;
        --registry) [[ $# -ge 2 ]] || die '--registry requires a destination'; registry=$2; shift 2 ;;
        -h|--help)
            echo 'Usage: build.sh [--push] [--registry HOST/NAMESPACE]'
            echo 'Build root context with Maven wrapper; tag APP_IMAGE and Git version. Optional push requires prior docker login.'
            exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
preflight
need git
prepare_env
require_env
docker buildx version >/dev/null 2>&1 || die 'Docker Buildx plugin required.'
revision=$(git -C "$ROOT" rev-parse HEAD)
short=$(git -C "$ROOT" rev-parse --short=12 HEAD)
description=$(git -C "$ROOT" describe --tags --always --dirty)
version=$(printf '%s-%s' "$description" "$short" | tr '/:+' '---' | cut -c1-128)
image=$(config_value services app image)
[[ $image != *@* ]] || die 'APP_IMAGE must be a writable tag, not a digest, when building.'
tag="${IMAGE_NAME:-petclinic}:$version"
if $push; then
    [[ -n $registry && $registry != *://* && $registry != *' '* ]] || die 'Set REGISTRY or --registry to HOST/NAMESPACE without a URL scheme.'
    tag="${registry%/}/${IMAGE_NAME:-petclinic}:$version"
fi
docker build --file "$ROOT/docker/Dockerfile" \
    --build-arg "SOURCE=${SOURCE:-https://github.com/ThinkWithOps/thinkwithops-petclinic-production}" \
    --build-arg "REVISION=$revision" --build-arg "VERSION=$version" \
    --build-arg "LICENSES=${LICENSES:-Apache-2.0}" \
    --tag "$image" --tag "$tag" "$ROOT"
bytes=$(docker image inspect "$image" --format '{{.Size}}')
printf 'Built %s and %s\nImage size: %s bytes (uncompressed engine size; target <200000000).\n' "$image" "$tag" "$bytes"
docker history --no-trunc --format '{{.Size}}\t{{.CreatedBy}}' "$image"
if ((bytes >= 200000000)); then
    printf 'SIZE BUDGET EXCEEDED: record measurements and evaluate the optional jlink follow-up in ADR 0001 before release.\n' >&2
fi
if $push; then docker push "$tag"; fi
