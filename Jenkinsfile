// Same stage contract as .github/workflows/ci.yml, for environments that
// can't use SaaS runners. See docs/ci-portability.md for the mapping and
// docs/adr/0007-jenkins-and-nexus-responsibilities.md for why this exists
// alongside GitHub Actions rather than instead of it.
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        IMAGE_NAME = 'petclinic-local'
        SHORT_SHA  = "${env.GIT_COMMIT.take(12)}"
    }

    stages {
        stage('verify') {
            steps {
                sh './mvnw -B -ntp verify'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    archiveArtifacts artifacts: 'target/spring-petclinic-*.jar', fingerprint: true
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

        stage('quality gate wait') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('image build') {
            steps {
                sh '''
                    docker build --file docker/Dockerfile \
                        --build-arg REVISION="$GIT_COMMIT" \
                        --build-arg VERSION="$SHORT_SHA" \
                        --tag "$IMAGE_NAME:$SHORT_SHA" .
                '''
            }
        }

        stage('trivy') {
            steps {
                sh '''
                    trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 \
                        --format sarif --output trivy-results.sarif \
                        --ignorefile .trivyignore \
                        "$IMAGE_NAME:$SHORT_SHA"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-results.sarif', allowEmptyArchive: true
                }
            }
        }

        stage('checkov') {
            steps {
                sh 'checkov --config-file .checkov.yaml'
            }
        }

        stage('deploy JAR to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'NEXUS_DEPLOY_CREDENTIALS',
                        usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        settings_file=$(mktemp)
                        trap 'rm -f "$settings_file"' EXIT
                        sed -e "s#{{NEXUS_USER}}#$NEXUS_USER#g" -e "s#{{NEXUS_PASS}}#$NEXUS_PASS#g" \
                            ci/settings.xml.template > "$settings_file"
                        ./mvnw -B -ntp -s "$settings_file" deploy \
                            -DskipTests \
                            -DaltDeploymentRepository=nexus::default::http://nexus:8081/repository/maven-releases/
                    '''
                }
            }
        }
    }
}
