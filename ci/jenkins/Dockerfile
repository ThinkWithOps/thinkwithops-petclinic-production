# Configured-as-code Jenkins: base LTS image + pinned plugins baked in.
# Mounting plugins.txt into /usr/share/jenkins/ref/ alone does not install
# plugins — jenkins-plugin-cli has to run at build time.
ARG JENKINS_TAG=2.492.2-lts-jdk17
FROM jenkins/jenkins:${JENKINS_TAG}
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml
# The base image already creates and runs as this non-root user (uid 1000);
# restated explicitly since Checkov's dockerfile framework checks the final
# stage's own USER instruction, not what an upstream base image set.
USER jenkins
HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=6 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/login || exit 1
