# ADR 0007: Jenkins + Nexus responsibilities, and release-please over versions-maven-plugin

Status: accepted.

## Problem and options

**Jenkins/Nexus.** GitHub Actions can't be assumed available everywhere this pipeline's design gets reused (an internal network with no SaaS runner access, an air-gapped environment). Something has to demonstrate the same stage contract running self-hosted. Options: skip this entirely (GitHub Actions only), or add a self-hosted pipeline that proves the design is CI-platform-agnostic.

**Versioning.** Maven versioning needs exactly one writer. `versions-maven-plugin` (imperative, `mvn versions:set`) and `release-please` (Conventional-Commits-driven, opens a release PR with the version bump) both know how to write `pom.xml`'s `<version>`. Running both risks one clobbering the other's write in some ordering of CI steps, or a human running `versions:set` manually against a version release-please already bumped.

## Decision

- Jenkins runs the same stage contract as `.github/workflows/ci.yml` (`Jenkinsfile`: verify, sonar, quality-gate wait, image build, trivy, checkov, deploy to Nexus), proving the pipeline design isn't tied to GitHub Actions. It is not a replacement for GitHub Actions on this repo — GHCR publish and release promotion stay GitHub-Actions-only since this is a public GitHub repo.
- Nexus is scoped to versioned JAR artifacts only (`mvn deploy` target), not container images — GHCR already owns image distribution, and duplicating that in Nexus would be the "two tools, one job" anti-pattern this project avoids.
- `versions-maven-plugin` is removed from scope entirely. `release-please` (`release-type: maven`) is the only writer of `pom.xml`'s version, driven by Conventional Commit messages on squash-merged PRs. `mvnw` commands that need the "current" version (e.g. tagging a Docker image) read it from Maven's own effective POM, never invoke `versions:set`.

## Trade-offs

Losing `versions-maven-plugin` means there's no ad-hoc `mvn versions:set -DnewVersion=...` escape hatch — every version bump has to flow through a merged Conventional Commit and the release-please PR. That's the point: deterministic versioning requires exactly one path to a version bump, and human "just set it to X" convenience is what created the two-writer conflict in the first place.

## Enterprise scale

At scale, Nexus would also host a Docker/OCI-format repository as a private mirror or pull-through cache to reduce GHCR/Docker Hub egress dependence, and Jenkins credentials would come from a real secrets manager (Vault, cloud KMS) rather than Jenkins' own credential store.
