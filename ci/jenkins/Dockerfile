# Configured-as-code Jenkins: base LTS image + pinned plugins + the CLI tools the
# Jenkinsfile calls. Mounting plugins.txt into /usr/share/jenkins/ref/ alone does
# not install plugins — jenkins-plugin-cli has to run at build time.
#
# The Docker CLI/Compose/Buildx and Trivy are static binaries copied from their
# official images. Jenkins drives the HOST Docker daemon through the mounted
# /var/run/docker.sock (see ci/compose.yaml); no second daemon runs in here.
ARG JENKINS_TAG=2.492.2-lts-jdk17
ARG DOCKER_CLI_TAG=27.5.1-cli
ARG TRIVY_TAG=0.74.0

FROM docker:${DOCKER_CLI_TAG} AS docker-cli
FROM aquasec/trivy:${TRIVY_TAG} AS trivy

FROM jenkins/jenkins:${JENKINS_TAG}
ARG CHECKOV_VERSION=3.3.22

USER root
# ca-certificates/curl/git are normally present in the base image; listed so the
# Jenkinsfile's requirements are explicit. python3-venv brings pip (via ensurepip)
# without touching the system Python (PEP 668). apt versions are not pinned: the
# Debian point-release string changes under the base image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git python3 python3-venv shellcheck \
    && python3 -m venv /opt/checkov \
    && /opt/checkov/bin/pip install --no-cache-dir "checkov==${CHECKOV_VERSION}" \
    && ln -s /opt/checkov/bin/checkov /usr/local/bin/checkov \
    && rm -rf /var/lib/apt/lists/* /root/.cache

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=trivy /usr/local/bin/trivy /usr/local/bin/trivy

# Fail the image build, not the first pipeline run, if any required tool is missing.
RUN docker --version \
    && docker compose version \
    && docker buildx version \
    && trivy --version \
    && checkov --version \
    && shellcheck --version \
    && curl --version | head -n 1 \
    && git --version \
    && python3 --version \
    && /opt/checkov/bin/pip --version

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
# --latest=false: without it the CLI upgrades transitive dependencies to their newest
# release, which can require a newer Jenkins core than the pinned LTS.
RUN jenkins-plugin-cli --latest=false \
    --plugin-file /usr/share/jenkins/ref/plugins.txt

# Kept OUTSIDE /var/jenkins_home: that path is a named volume, and a volume that
# already exists keeps its old files, so a rebuilt image's casc.yaml would be
# silently ignored. ci/compose.yaml points CASC_JENKINS_CONFIG here.
COPY casc.yaml /usr/share/jenkins/casc/casc.yaml
# Trivy's vulnerability DB is cached in the persistent Jenkins home volume.
ENV TRIVY_CACHE_DIR=/var/jenkins_home/.cache/trivy

# The base image already creates and runs as this non-root user (uid 1000);
# restated explicitly since Checkov's dockerfile framework checks the final
# stage's own USER instruction, not what an upstream base image set.
USER jenkins
HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=6 \
    CMD curl --fail --silent --output /dev/null http://127.0.0.1:8080/login || exit 1
