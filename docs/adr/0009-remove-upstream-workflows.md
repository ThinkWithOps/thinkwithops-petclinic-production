# ADR 0009: remove upstream GitHub Actions workflows

Status: accepted.

## Problem and options

Upstream Spring PetClinic ships `.github/workflows/maven-build.yml`, `gradle-build.yml`, and `deploy-and-test-cluster.yml`. This project follows the Maven path only (see ADR 0004 / repository conventions: leave sibling Gradle files untouched but don't build CI around them), and `deploy-and-test-cluster.yml` targets upstream's own Kubernetes demo deployment flow, which V1/V2 replace with this repo's own `docker/` and future `k8s/` operational layers. Options: keep all three and add v2's workflows alongside them; keep only `maven-build.yml`; remove all three and replace with a single purpose-built `ci.yml`.

## Decision

Remove all three upstream workflows. `maven-build.yml` and `gradle-build.yml` are both superseded by `.github/workflows/ci.yml`'s `build-test` job, which runs the identical `./mvnw verify` but adds the quality/security/publish stages this milestone requires — keeping the upstream file alongside it would just run redundant, weaker CI on every push. `deploy-and-test-cluster.yml` deploys to upstream's own demo infrastructure conventions, which this repo does not use (see `docker/compose.yaml` from v1, and `k8s/` conventions to come in v4); keeping it would give false signal about a deployment path this repo doesn't actually exercise.

## Trade-offs

This repo no longer runs upstream's original CI on its own terms — if upstream evolves its Maven build in a way this repo's `ci.yml` doesn't track (a new required Java version, a new Maven goal), that has to be caught by watching upstream directly, not by inheriting their workflow file.

## Enterprise scale

At scale, track upstream's workflow changes via the `upstream` remote (already kept per ADR 0004) as part of a periodic upstream-diff review, rather than re-vendoring their CI files wholesale.
