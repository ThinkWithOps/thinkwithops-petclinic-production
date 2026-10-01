# V2 architecture: CI/CD pipeline

Status: the GitHub Actions path (CI, release-please, digest promotion) is
**runtime-verified** on real runs, including release `petclinic-v1.1.0`. The
self-hosted Jenkins/SonarQube/Nexus path is **implementation prepared; runtime
verification pending** a real Docker engine (see `docs/validation/v2-cicd.md`).

## PR path

```mermaid
flowchart TD
    PR[Pull request] --> BT[build-test: mvnw verify once]
    BT --> QG[quality-gate: SonarQube Cloud, re-runs mvnw verify to regenerate coverage]
    BT --> IMG[image: buildx build, load only, export image.tar artifact]
    IMG --> TR[trivy: scan the exact image.tar; SARIF to code scanning; CycloneDX SBOM]
    PR --> CS[config-scan: checkov dockerfile+github_actions, shellcheck scripts/]
    QG & TR & CS -->|all required checks green| MERGE[Merge blocked until all pass, if branch protection requires these checks]
```

## Main path

```mermaid
flowchart TD
    M[Push to main after merge] --> BT2[build-test]
    BT2 --> QG2[quality-gate]
    BT2 --> IMG2[image build]
    IMG2 --> TR2[trivy]
    M --> CS2[config-scan]
    BT2 & QG2 & TR2 & CS2 --> PUB[publish: load the SAME image.tar, push to GHCR as sha-short, attach SBOM]
```

## Release path

```mermaid
flowchart TD
    MAIN[main advances] --> RP[release-please: opens/updates release PR from Conventional Commits]
    RP -->|release PR merged| REL[GitHub Release created]
    REL --> PROMOTE[promote-by-digest: pull sha-short image, docker buildx imagetools create -> petclinic-vX.Y.Z tag, same manifest digest]
    PROMOTE --> PROOF[Job log asserts source digest == promoted manifest digest]
```

## Gates

Merge blocking applies only where branch protection requires the named check
(`docs/branch-protection.md`); that setting is not confirmed applied on this repo.

| Gate | Enforced by | Blocks |
|---|---|---|
| Tests pass | `build-test` job (`mvnw verify`) | PR merge (required check) |
| Coverage/code smells | `quality-gate` job (SonarQube Cloud) | PR merge (required check) |
| No fixable CRITICAL CVEs | `trivy` job | PR merge (required check) |
| IaC/config hygiene | `config-scan` job (Checkov + shellcheck) | PR merge (required check) |
| Direct pushes to main | Branch protection (see `docs/branch-protection.md`) | All non-PR pushes |
| Conventional Commit PR titles | Squash-merge + release-please | Deterministic versioning |

## Artifact flow

`build-test` produces the JAR + coverage report as workflow artifacts.
`image` builds one image and exports it as `image.tar` — never pushed on PRs.
`trivy` scans that same `image.tar`, never a separately built image. On push
to main, `publish` loads that identical `image.tar` and pushes it to GHCR as
`sha-<short>` — no second build. `release.yml` never invokes `docker build`;
it pulls `sha-<short>` and retags it to the release's semver tag by digest.
See `docs/adr/0005-build-once-promote-by-digest.md`.

## Self-hosted parity (implementation prepared; runtime verification pending)

`ci/compose.yaml` + `Jenkinsfile` run an **equivalent** stage contract
(`docs/ci-portability.md`, which lists the differences) for environments
without GitHub-hosted runner access: Jenkins orchestrates, a local SonarQube
instance is the quality gate (Jenkins waits on a SonarQube webhook), and Nexus
receives the versioned JAR instead of GHCR receiving an image push. Jenkins
builds on the host Docker daemon through the mounted socket and runs Trivy,
Checkov, ShellCheck and the SBOM step from tools baked into its image.

Base images here are pinned by version tag, not digest: the app stack under
`docker/` is digest-pinned, but Jenkins, SonarQube, Nexus and the tool images
copied into the Jenkins image (Docker CLI, Trivy) are not. GitHub Actions and
release promotion are the verified path; nothing in this self-hosted section
should be read as verified until Part B runs.
