# ADR 0005: build once, promote by digest

Status: accepted.

## Problem and options

V1 has no CI at all: nothing builds, tests, scans or ships the app automatically. Adding CI naively — one workflow that builds+tests on PRs, and a separate release workflow that rebuilds the image from the release tag — creates a real gap: the image a release ships is not provably the image that was tested and scanned. A rebuild days later can pick up a different base-image layer, a different transitive dependency resolution, or simply drift from the commit that was actually reviewed. Options considered: (a) rebuild at release time, accepting the gap; (b) build once on merge to main, scan that exact image, push it by its commit SHA, and have the release step retag/promote that same digest with no rebuild.

## Decision

Option (b). `.github/workflows/ci.yml`'s `image`/`trivy`/`publish` jobs build one image per push to main, scan it, and push it to GHCR tagged `sha-<short>`. `.github/workflows/release.yml` never runs `docker build` — it pulls the existing `sha-<short>` tag and uses `docker buildx imagetools create` to add the semver tag pointing at the identical manifest digest, then asserts the digests match in the job log (see `promote-by-digest` job).

## Trade-offs

The PR-time `image` job (unpushed, artifact-exported) and the main-branch `publish` job both build — technically two builds per merged PR, once for PR validation and once on push to main after merge, which is unavoidable without cross-workflow artifact sharing across differently-triggered runs. What matters is there is exactly one build on the path from "merged to main" to "released" — `publish` builds once, and release.yml promotes that build's own digest, never re-invoking Docker build.

## Enterprise scale

At scale, replace `docker buildx imagetools create` retagging with signed provenance (SLSA/cosign attestations) so digest promotion is independently verifiable, not just asserted in a job log. Consider an artifact registry that supports immutable tags natively to make rebuild-at-release structurally impossible rather than merely avoided by workflow design.
