# Configured-as-code Jenkins: base LTS image + pinned plugins baked in.
# Mounting plugins.txt into /usr/share/jenkins/ref/ alone does not install
# plugins — jenkins-plugin-cli has to run at build time.
ARG JENKINS_TAG=2.492.2-lts-jdk17
FROM jenkins/jenkins:${JENKINS_TAG}
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml
