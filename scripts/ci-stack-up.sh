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

# Set KEY=value in ci/.env: replace the line if the key exists, append otherwise.
# Idempotent, and keeps the file private (0600) since it holds generated passwords.
set_env_value() {
    python3 - "$CI_ENV_FILE" "$1" "$2" <<'PY'
import os
import pathlib
import signal
import sys
import tempfile
path, key, value = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = path.read_text().splitlines()
entry = f'{key}={value}'
for i, line in enumerate(lines):
    if line.startswith(f'{key}='):
        lines[i] = entry
        break
else:
    lines.append(entry)

def interrupted(signum, frame):
    raise SystemExit(128 + signum)

for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
    signal.signal(signum, interrupted)

fd, tmp_name = tempfile.mkstemp(prefix=f'{path.name}.set.', suffix='.tmp', dir=path.parent)
tmp = pathlib.Path(tmp_name)
try:
    with os.fdopen(fd, 'w') as stream:
        stream.write('\n'.join(lines) + '\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)
finally:
    tmp.unlink(missing_ok=True)
PY
}

if [[ $action == down ]]; then
    # An older ci/.env may predate DOCKER_GID; compose still needs a value to parse the file.
    : "${DOCKER_GID:=0}"
    export DOCKER_GID
    ci_compose down
    exit 0
fi

need python3

# Build ci/.env in a temp file in the same directory and move it into place only once
# complete, so an interrupted or failed run can never leave a half-generated ci/.env
# with literal placeholder passwords (a rerun would skip generation and reuse them).
tmp_env=
cleanup_tmp_env() { [[ -z $tmp_env ]] || rm -f "$tmp_env"; }
trap cleanup_tmp_env EXIT

if [[ ! -f $CI_ENV_FILE ]]; then
    printf 'Creating %s with random credentials (never committed).\n' "$CI_ENV_FILE" >&2
    tmp_env=$(umask 077; mktemp "$CI_DIR/.env.tmp.XXXXXX")
    cp "$CI_DIR/.env.example" "$tmp_env"
    python3 - "$tmp_env" <<'PY'
import pathlib
import secrets
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
while 'REPLACE_WITH_RANDOM_PASSWORD' in text:
    text = text.replace('REPLACE_WITH_RANDOM_PASSWORD', secrets.token_hex(16), 1)
path.write_text(text)
PY
    if grep -q 'REPLACE_WITH_RANDOM_PASSWORD' "$tmp_env"; then
        die "Credential generation left placeholder values in $tmp_env; $CI_ENV_FILE was not created."
    fi
    chmod 600 "$tmp_env"
    mv -f "$tmp_env" "$CI_ENV_FILE"
    tmp_env=
fi

# Jenkins drives the HOST Docker daemon through the mounted socket, so its uid needs
# the socket's group as a supplemental group (group_add in ci/compose.yaml). The path
# is fixed because ci/compose.yaml always mounts /var/run/docker.sock.
readonly DOCKER_SOCK=/var/run/docker.sock
[[ -S $DOCKER_SOCK ]] || die "Docker socket $DOCKER_SOCK not found. The Jenkins container needs the host Docker daemon's socket."
docker_gid=$(stat -c '%g' "$DOCKER_SOCK") || die "Could not read the group ID of $DOCKER_SOCK."
[[ $docker_gid =~ ^[0-9]+$ ]] || die "Unexpected group ID for $DOCKER_SOCK: $docker_gid"
set_env_value DOCKER_GID "$docker_gid"
printf 'Docker socket %s group ID: %s (written to %s)\n' "$DOCKER_SOCK" "$docker_gid" "$CI_ENV_FILE" >&2

ci_compose up -d --build
ci_compose ps

cat <<'EOF'

Stack starting (first start takes a few minutes: SonarQube and Nexus each need
1-3 minutes before they answer). SonarQube's embedded Elasticsearch needs
vm.max_map_count >= 262144 on the Docker host; if sonarqube keeps restarting,
run on the HOST (not in a container):
    sudo sysctl -w vm.max_map_count=262144

First-run manual steps (do these in each tool's UI — credentials are stored as
Jenkins credentials afterward, never written to this repo):
  1. SonarQube (default http://localhost:9000, admin/admin on first login):
     change the admin password, then create a project + generate a token
     (My Account > Security). Store it as a Jenkins "Secret text" credential
     named SONAR_TOKEN_LOCAL. The Jenkins-side server entry "local-sonarqube"
     (http://sonarqube:9000) is already created by ci/jenkins/casc.yaml.
  2. SonarQube webhook (REQUIRED): Administration > Configuration > Webhooks >
     Create, URL  http://jenkins:8080/sonarqube-webhook/  (no secret needed).
     The pipeline's waitForQualityGate step only returns when SonarQube calls
     this URL; without it the quality gate stage waits until its 5-minute
     timeout and fails.
  3. Nexus (default http://localhost:8081): find the generated initial admin
     password inside the nexus-data volume
     (`docker compose --env-file ci/.env -f ci/compose.yaml exec nexus cat /nexus-data/admin.password`),
     log in, change it, and make sure a hosted "maven-releases" repository
     exists (it does by default). Create a deployment user and store
     username+password as a Jenkins "Username with password" credential named
     NEXUS_DEPLOY_CREDENTIALS.
  4. Jenkins (http://localhost:8090, credentials from ci/.env
     JENKINS_ADMIN_USER/JENKINS_ADMIN_PASSWORD): confirm the seeded
     "petclinic-ci" pipeline job exists (from ci/jenkins/casc.yaml), then
     trigger a build. The job reads the Jenkinsfile from the main branch of
     the GitHub repo, so merge Jenkinsfile changes to main first.

Run `ci-stack-up.sh --down` to stop the stack.
EOF
