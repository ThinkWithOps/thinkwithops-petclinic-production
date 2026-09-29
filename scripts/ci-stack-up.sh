#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/common.sh"

CI_DIR="$ROOT/ci"
CI_ENV_FILE="$CI_DIR/.env"

usage() {
    echo 'Usage: ci-stack-up.sh [--down]'
    echo 'Bring up the self-hosted CI stack (Jenkins + local SonarQube + Nexus).'
    echo '--down stops and removes the stack (volumes kept).'
}

action=up
while (($#)); do
    case $1 in
        --down) action=down; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

need docker
docker compose version >/dev/null 2>&1 || die 'Docker Compose v2+ plugin required.'
docker info >/dev/null 2>&1 || die 'Docker daemon unavailable.'

ci_compose() { docker compose --env-file "$CI_ENV_FILE" -f "$CI_DIR/compose.yaml" "$@"; }

if [[ $action == down ]]; then
    ci_compose down
    exit 0
fi

if [[ ! -f $CI_ENV_FILE ]]; then
    printf 'Creating %s with random credentials (never committed).\n' "$CI_ENV_FILE" >&2
    (umask 077; cp "$CI_DIR/.env.example" "$CI_ENV_FILE")
    need python3
    python3 - "$CI_ENV_FILE" <<'PY'
import pathlib, secrets, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace('REPLACE_WITH_RANDOM_PASSWORD', secrets.token_hex(16), 1)
text = text.replace('REPLACE_WITH_RANDOM_PASSWORD', secrets.token_hex(16), 1)
path.write_text(text)
PY
fi

ci_compose up -d --build
ci_compose ps

cat <<'EOF'

Stack starting. SonarQube's embedded Elasticsearch needs vm.max_map_count >= 262144
on the Docker host; if sonarqube keeps restarting, run on the HOST (not in a
container):
    sudo sysctl -w vm.max_map_count=262144

First-run manual steps (do these in each tool's UI — credentials are stored as
Jenkins credentials afterward, never written to this repo):
  1. SonarQube (default http://localhost:9000, admin/admin on first login):
     change the admin password, then create a project + generate a token
     (My Account > Security). Store it as a Jenkins "Secret text" credential
     named SONAR_TOKEN_LOCAL.
  2. Nexus (default http://localhost:8081): find the generated initial admin
     password inside the nexus-data volume
     (`docker compose -f ci/compose.yaml exec nexus cat /nexus-data/admin.password`),
     log in, change it, and create a "maven-releases"/"maven-snapshots"
     hosted repository (or use the defaults). Create a deployment user/token
     and store username+password as a Jenkins "Username with password"
     credential named NEXUS_DEPLOY_CREDENTIALS.
  3. Jenkins (http://localhost:8090, credentials from ci/.env
     JENKINS_ADMIN_USER/JENKINS_ADMIN_PASSWORD): confirm the seeded
     "petclinic-ci" pipeline job exists (from ci/jenkins/casc.yaml). Add a
     Docker Hub / GHCR credential if Jenkins needs to pull/push images from
     a private registry.

Run `ci-stack-up.sh --down` to stop the stack.
EOF
