# CI stage contract portability

The pipeline's stage contract — verify, quality gate, image build, vulnerability
scan, config scan, publish — is implemented three times in this repo:
`.github/workflows/ci.yml` (GitHub Actions), `Jenkinsfile` (self-hosted
Jenkins), and, illustratively, GitLab CI below. The point is that no stage
depends on a GitHub-Actions-only or Jenkins-only capability; each is a
`./mvnw`/`docker`/`trivy`/`checkov` invocation any CI platform can run.

## Stage contract

| Stage | Command | GitHub Actions job | Jenkins stage |
|---|---|---|---|
| verify | `./mvnw -B -ntp verify` | `build-test` | `verify` |
| quality gate | `./mvnw ... sonar-maven-plugin:sonar` | `quality-gate` | `sonar (local)` + `quality gate wait` |
| image build | `docker build -f docker/Dockerfile .` | `image` | `image build` |
| vulnerability scan | `trivy image ...` | `trivy` | `trivy` |
| config scan | `checkov --config-file .checkov.yaml` | `config-scan` | `checkov` |
| publish/deploy | `docker push` (GHCR) / `mvn deploy` (Nexus) | `publish` | `deploy JAR to Nexus` |

## GitLab CI equivalent (illustrative, not run in this repo)

```yaml
stages: [verify, quality-gate, image, scan, publish]

verify:
  stage: verify
  script: ./mvnw -B -ntp verify
  artifacts:
    paths: [target/spring-petclinic-*.jar, target/surefire-reports/, target/site/jacoco/]

quality-gate:
  stage: quality-gate
  script: ./mvnw -B -ntp org.sonarsource.scanner.maven:sonar-maven-plugin:5.1.0.4751:sonar -Dsonar.qualitygate.wait=true

image:
  stage: image
  script: docker build -f docker/Dockerfile -t "$CI_REGISTRY_IMAGE:sha-$CI_COMMIT_SHORT_SHA" .

trivy:
  stage: scan
  script: trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 --trivyignores .trivyignore "$CI_REGISTRY_IMAGE:sha-$CI_COMMIT_SHORT_SHA"

checkov:
  stage: scan
  script: checkov --config-file .checkov.yaml

publish:
  stage: publish
  script: docker push "$CI_REGISTRY_IMAGE:sha-$CI_COMMIT_SHORT_SHA"
  only: [main]
```

The differences between platforms are entirely orchestration syntax
(`jobs:`/`stages:` shape, artifact-passing mechanics, credential injection) —
never a stage's actual command. That's the portability property this
document exists to make explicit.
