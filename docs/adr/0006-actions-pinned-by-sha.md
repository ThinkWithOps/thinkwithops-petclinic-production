# ADR 0006: pin GitHub Actions and tool responsibilities

Status: partially accepted — SHA pinning is a documented TODO, not yet done (see below).

## Problem and options

Two separate problems bundled into one ADR because they're both "which tool does what, and why not the alternative": (1) supply-chain risk from floating Action tags, and (2) which quality-gate/scanning tools run where.

**Action pinning.** A `uses: actions/checkout@v4`-style reference can be repointed by whoever controls that tag; the scanner and build actions in this pipeline (Trivy, Checkov, SBOM, release-please) are themselves high-value supply-chain targets since they run with `contents:`/`packages:`/`security-events:` permissions. Options: floating major-version tags (convenient, trusts the publisher's tag hygiene) vs. pinned commit SHAs (immune to tag repointing, requires active maintenance to bump).

**Tool responsibilities.** GitHub Actions vs. a self-hosted runner for the primary pipeline; SonarQube Cloud vs. self-hosted SonarQube for the PR-blocking quality gate; Checkov vs. hadolint for Dockerfile linting.

## Decision

- GitHub Actions is primary CI/CD for this public repo (no infra to host, native PR integration).
- SonarQube Cloud is the quality gate on GitHub PRs specifically because SonarQube Community Edition cannot decorate PRs with inline findings, and a locally-hosted SonarQube instance is not reachable by GitHub-hosted runners without exposing it publicly (not something this project accepts as a trust boundary). Self-hosted SonarQube (`ci/compose.yaml`) exists only for the Jenkins path, where the runner *can* reach it because they're on the same host/network.
- Checkov covers Dockerfile + GitHub Actions config scanning; no separate hadolint step — Checkov's `dockerfile` framework covers the same class of findings (missing USER, ADD vs COPY, etc.) and adding a second tool for overlapping checks would violate the "no duplicate tools" rule.
- `.github/workflows/ci.yml` and `.github/workflows/release.yml` currently pin actions by **tag**, not commit SHA, with an explicit `# TODO: pin to commit SHA` comment on every `uses:` line. This is a deliberate, honestly-labeled gap: this ADR's author (an AI agent, at the time of v2's initial build) did not have a way to independently verify real commit SHAs for each action version without a live network/registry lookup, and shipping fabricated-looking SHA values would be worse than an honest floating-tag pin with a visible TODO — a wrong SHA that merely *looks* verified is a worse security posture than a floating tag everyone knows is floating.

## Trade-offs

Floating tags are the accepted interim risk. Every workflow file marks exactly where SHA pinning needs to happen, so closing this gap is a mechanical, reviewable follow-up (resolve each `uses: owner/repo@vX` to its tag's commit SHA, e.g. via `gh api repos/<owner>/<repo>/git/refs/tags/<tag>`) rather than a rediscovery task.

## Enterprise scale

At scale: pin every action by SHA (close the TODO above), enable Dependabot/Renovate for Actions so SHA bumps are automated PRs, and consider an internal Actions proxy/allowlist so only vetted actions can run at all.
