# ADR 0006: pin GitHub Actions and tool responsibilities

Status: accepted — SHA pinning done (2026-09-29, via `gh api repos/<owner>/<repo>/git/refs/tags/<tag>` once network/`gh` access was available; see Trade-offs).

## Problem and options

Two separate problems bundled into one ADR because they're both "which tool does what, and why not the alternative": (1) supply-chain risk from floating Action tags, and (2) which quality-gate/scanning tools run where.

**Action pinning.** A `uses: actions/checkout@v4`-style reference can be repointed by whoever controls that tag; the scanner and build actions in this pipeline (Trivy, Checkov, SBOM, release-please) are themselves high-value supply-chain targets since they run with `contents:`/`packages:`/`security-events:` permissions. Options: floating major-version tags (convenient, trusts the publisher's tag hygiene) vs. pinned commit SHAs (immune to tag repointing, requires active maintenance to bump).

**Tool responsibilities.** GitHub Actions vs. a self-hosted runner for the primary pipeline; SonarQube Cloud vs. self-hosted SonarQube for the PR-blocking quality gate; Checkov vs. hadolint for Dockerfile linting.

## Decision

- GitHub Actions is primary CI/CD for this public repo (no infra to host, native PR integration).
- SonarQube Cloud is the quality gate on GitHub PRs specifically because SonarQube Community Edition cannot decorate PRs with inline findings, and a locally-hosted SonarQube instance is not reachable by GitHub-hosted runners without exposing it publicly (not something this project accepts as a trust boundary). Self-hosted SonarQube (`ci/compose.yaml`) exists only for the Jenkins path, where the runner *can* reach it because they're on the same host/network.
- Checkov covers Dockerfile + GitHub Actions config scanning; no separate hadolint step — Checkov's `dockerfile` framework covers the same class of findings (missing USER, ADD vs COPY, etc.) and adding a second tool for overlapping checks would violate the "no duplicate tools" rule.
- `.github/workflows/ci.yml` and `.github/workflows/release.yml` pin every action by commit SHA, with the released version kept as a trailing comment (e.g. `uses: actions/checkout@11d5960... # v4.2.2`). When this file was first written, the author (an AI agent, at v2's initial build) had no way to independently verify real commit SHAs without a live registry lookup, and shipped tag-only pins with an explicit `# TODO: pin to commit SHA` on every line rather than fabricate SHA values that would look verified but weren't — a wrong SHA that merely *looks* verified is a worse security posture than a floating tag everyone knows is floating. Once `gh` CLI access to the real GitHub API was available, every SHA was resolved and verified (`gh api repos/<owner>/<repo>/git/refs/tags/<tag>`) and the TODOs closed.

## Trade-offs

SHA-pinned actions never auto-update; a version bump now requires a deliberate PR that re-resolves the tag's SHA, rather than picking up patches silently. That's the point — see Enterprise scale below for how to make the bump itself low-effort without giving up the pin.

## Enterprise scale

At scale: enable Dependabot/Renovate for GitHub Actions so SHA bumps arrive as automated PRs (they resolve and verify the new SHA for you), and consider an internal Actions proxy/allowlist so only vetted actions can run at all.
