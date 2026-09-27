# ADR 0004: separate operational Compose stack and preserve upstream

Status: accepted.

## Problem and options

The imported root `docker-compose.yml` launches developer databases, publishes database ports and is used by upstream development tooling. Replacing it would blur ownership and could break that workflow. Options: replace it, extend it, or maintain a separate complete operational stack.

## Decision

Keep root Compose, `k8s/`, application/tests and Gradle files unchanged. Put V1 under `docker/compose.yaml`; use the repository root as its build context. All project scripts explicitly select this file, a private env file and a stable project name. Upstream attribution lives in this repository's own `README.md` (Attribution/License sections) rather than a separate mirrored file; the Apache license and `upstream` remote are preserved.

This repository began as copied files, not imported Git history. Commit `9f86b9b` records that supplied baseline; no upstream revision provenance is invented. `upstream` is a remote for reference and future comparison, not evidence that histories are related.

## Trade-offs

Two Compose files require explicit documentation. Running plain `docker compose up` in the root selects the upstream development stack, not V1. Project helpers avoid that ambiguity. The build context is an allowlist; `.git`, `.env`, docs, tools and generated artifacts cannot enter the image.

## Enterprise scale

Keep operational ownership explicit. Track upstream changes by reviewed imports or a documented fork strategy. Promote immutable application images through environment-specific deployment configuration, maintaining one repository and immutable milestone tags.
