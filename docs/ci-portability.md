# CI stage contract portability

The pipeline's stage contract — verify, quality gate, image build, vulnerability
scan, config scan, SBOM, publish — is implemented twice in this repo and
sketched once for GitLab:
`.github/workflows/ci.yml` (GitHub Actions, runtime-verified), `Jenkinsfile`
(self-hosted Jenkins, implementation prepared; runtime verification pending)
and, illustratively, GitLab CI below. The contract is *equivalent*, not
identical — see "Differences" below. The point is that no stage
depends on a GitHub-Actions-only or Jenkins-only capability; each is a
`./mvnw`/`docker`/`trivy`/`checkov` invocation any CI platform can run.

## Stage contract

| Stage | Command | GitHub Actions job | Jenkins stage |
|---|---|---|---|
| verify | `./mvnw -B -ntp verify` | `build-test` | `verify` |
| quality gate | `./mvnw ... sonar-maven-plugin:sonar` | `quality-gate` | `sonar (local)` + `quality gate wait` |
| image build | `docker build -f docker/Dockerfile .` | `image` | `image build` |
| vulnerability scan | `trivy image ...` on the saved image tarball | `trivy` | `trivy` |
| config scan | `checkov --config-file .checkov.yaml` | `config-scan` | `checkov + shellcheck` |
| shell lint | `shellcheck` over `scripts/**/*.sh` | `config-scan` | `checkov + shellcheck` |
| SBOM | `trivy image --format cyclonedx` on the same tarball | `trivy` | `sbom` |
| publish/deploy | `docker push` (GHCR) / `mvn deploy:deploy-file` (Nexus) | `publish` | `deploy JAR to Nexus` |

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

The differences between platforms are mostly orchestration syntax
(`jobs:`/`stages:` shape, artifact-passing mechanics, credential injection).
That's the portability property this document exists to make explicit. The
remaining real differences are listed here rather than hidden:

## Differences between GitHub Actions and Jenkins

| Area | GitHub Actions | Jenkins |
|---|---|---|
| Quality gate | SonarQube Cloud; `quality-gate` job re-runs `mvnw verify` to regenerate coverage, then `sonar:sonar -Dsonar.qualitygate.wait=true` | Local SonarQube; the `verify` stage's coverage is reused, then `waitForQualityGate`, which **requires** the SonarQube webhook `http://jenkins:8080/sonarqube-webhook/` |
| Image handoff | `image.tar` workflow artifact between jobs | `docker save` tarball in the workspace, scanned and SBOM'd in later stages, deleted in `post` |
| Scan results | SARIF uploaded to GitHub code scanning (Trivy and Checkov); SBOM as a workflow artifact | Trivy SARIF and SBOM archived as Jenkins build artifacts; Checkov result is the exit code only |
| Publish | Pushes the scanned image to GHCR, then release-please promotes it by digest | Never pushes an image; publishes the JAR the `verify` stage tested (checksum-guarded, `deploy:deploy-file`, no rebuild) to Nexus |
| Release | release-please + digest promotion (verified) | Not applicable |
| Tool delivery | Marketplace actions pinned by SHA | Tools baked into the Jenkins image: Docker CLI/Compose/Buildx and Trivy copied from official images pinned by version tag, Checkov pinned via pip, ShellCheck from apt (unpinned) |
| Base-image pinning | App images pinned by digest | Jenkins, SonarQube, Nexus, Docker CLI and Trivy images pinned by tag only |
| Runner | GitHub-hosted `ubuntu-latest` | Jenkins container using the host Docker daemon through `/var/run/docker.sock` |
