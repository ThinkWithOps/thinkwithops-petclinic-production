// Equivalent stage contract to .github/workflows/ci.yml, for environments that
// can't use SaaS runners. The commands match; orchestration and a few details
// differ (SonarQube is a local server, the JAR goes to Nexus instead of an image
// to GHCR, no code-scanning upload). See docs/ci-portability.md for the mapping
// and docs/adr/0007-jenkins-and-nexus-responsibilities.md for why this exists
// alongside GitHub Actions rather than instead of it.
//
// Status: implementation prepared; runtime verification pending a real Docker engine run.
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        IMAGE_NAME = 'petclinic-local'
    }

    stages {
        // GIT_COMMIT is not guaranteed to exist when a top-level `environment` block
        // is evaluated (that happens before the pipeline's own checkout), so the SHA
        // is read from the checked-out tree here and exported to every later stage.
        stage('prepare') {
            steps {
                script {
                    env.GIT_SHA = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
                    env.SHORT_SHA = env.GIT_SHA.take(12)
                }
                echo "Building ${env.GIT_SHA} (short ${env.SHORT_SHA})"
            }
        }

        stage('verify') {
            steps {
                sh './mvnw -B -ntp verify'
                // Pin down exactly which JAR was tested; the Nexus stage refuses to
                // publish anything whose checksum differs from this one.
                sh '''
                    set -eu
                    set -- target/spring-petclinic-*.jar
                    [ "$#" -eq 1 ] || { echo "expected exactly one verified JAR, found $#" >&2; exit 1; }
                    sha256sum "$1" > target/verified-jar.sha256
                    cat target/verified-jar.sha256
                '''
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    archiveArtifacts artifacts: 'target/spring-petclinic-*.jar, target/verified-jar.sha256', fingerprint: true
                }
            }
        }

        stage('sonar (local)') {
            steps {
                withSonarQubeEnv('local-sonarqube') {
                    sh './mvnw -B -ntp org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar'
                }
            }
        }

        // Needs the SonarQube webhook http://jenkins:8080/sonarqube-webhook/ —
        // without it this step waits out the timeout. See scripts/ci-stack-up.sh.
        stage('quality gate wait') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('image build') {
            steps {
                // Builds on the host daemon through the mounted docker socket. The
                // tarball is the single artifact that Trivy scans and the SBOM is
                // generated from, mirroring ci.yml's image.tar.
                sh '''
                    docker build --file docker/Dockerfile \
                        --build-arg REVISION="$GIT_SHA" \
                        --build-arg VERSION="$SHORT_SHA" \
                        --tag "$IMAGE_NAME:$SHORT_SHA" .
                    docker save "$IMAGE_NAME:$SHORT_SHA" --output image.tar
                '''
            }
        }

        stage('trivy') {
            steps {
                sh '''
                    trivy image --input image.tar \
                        --severity CRITICAL --ignore-unfixed --exit-code 1 \
                        --format sarif --output trivy-results.sarif \
                        --ignorefile .trivyignore
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-results.sarif', allowEmptyArchive: true
                }
            }
        }

        stage('checkov + shellcheck') {
            steps {
                sh 'checkov --config-file .checkov.yaml'
                sh '''
                    set -eu
                    find scripts -name '*.sh' -print0 | xargs -0 shellcheck
                '''
            }
        }

        stage('sbom') {
            steps {
                sh 'trivy image --input image.tar --format cyclonedx --output sbom.cdx.json'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sbom.cdx.json', allowEmptyArchive: true
                }
            }
        }

        // Publishes the JAR the verify stage tested — not a rebuild. deploy:deploy-file
        // uploads an existing file and runs no Maven lifecycle, so nothing is compiled
        // or repackaged here. The checksum guard fails the build if the file changed
        // since verify. The project's own pom.xml is uploaded as the artifact POM so
        // groupId/artifactId/version/parent are exactly what the build used.
        stage('deploy JAR to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'NEXUS_DEPLOY_CREDENTIALS',
                        usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        set -eu
                        sha256sum -c target/verified-jar.sha256
                        jar_file=$(cut -d' ' -f3- target/verified-jar.sha256)
                        settings_file=$(mktemp)
                        trap 'rm -f "$settings_file"' EXIT
                        python3 - "$settings_file" <<'PY'
import os
import pathlib
import sys
from xml.sax.saxutils import escape
text = pathlib.Path('ci/settings.xml.template').read_text()
text = text.replace('{{NEXUS_USER}}', escape(os.environ['NEXUS_USER']))
text = text.replace('{{NEXUS_PASS}}', escape(os.environ['NEXUS_PASS']))
pathlib.Path(sys.argv[1]).write_text(text)
PY
                        ./mvnw -B -ntp -s "$settings_file" deploy:deploy-file \
                            -Dfile="$jar_file" \
                            -DpomFile=pom.xml \
                            -DgeneratePom=false \
                            -DrepositoryId=nexus \
                            -Durl=http://nexus:8081/repository/maven-releases/
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f image.tar'
        }
    }
}
