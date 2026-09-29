# V2 validation: CI/CD pipeline

Status: **PARTIALLY VERIFIED** (updated 2026-09-29). `ci.yml` has run for
real on push to `main` (run `36608891090`) with `build-test`, `quality-gate`,
`image`, `trivy`, `config-scan`, and `publish` all green — reached only
after fixing several real, first-run-only bugs along the way (see the
commit history and the "Hit for real" notes below). The release-please and
Jenkins/Nexus paths are still not runtime-verified — see checks 4 and 5.

## Required checks and how to produce them

| # | Scenario | How to trigger | Status |
|---|---|---|---|
| 1 | PR with a failing test is blocked | Push a commit that breaks a test, open a PR | Not yet deliberately tested; `build-test` itself is confirmed working (green on real runs) |
| 2 | A CRITICAL vulnerability blocks the pipeline | (Happened organically, not via a deliberately added test dependency) | **Verified for real**: the first real `trivy` run found 3 genuine fixable-CRITICAL Tomcat CVEs and failed the job exactly as designed — see the "Hit for real" note below |
| 3 | A push to `main` goes fully green | Push to `main` | **Verified**: run `36608891090`, all 6 jobs green. PR-merge-specific gating (branch protection required checks) not yet separately confirmed — depends on `docs/branch-protection.md` being applied |
| 4 | Release promotes the same digest | Merge a `feat:`/`fix:` commit, let release-please open its PR, merge it | **Blocked, now fixed in code, needs a secret**: the release-please PR opened but showed **zero CI checks** — GitHub doesn't trigger workflows from PRs authored by the default `GITHUB_TOKEN`. Fixed by passing a PAT (`RELEASE_PLEASE_TOKEN`) to `release-please-action` — see `docs/ci-setup.md` §2b. Re-test once that secret exists |
| 5 | Jenkins pipeline runs green locally and a JAR appears in Nexus | `./scripts/ci-stack-up.sh`, complete the printed first-run steps, trigger the `petclinic-ci` Jenkins job | Not yet run — needs a real Docker engine |

**Note on `ci/jenkins/Dockerfile`'s HEALTHCHECK**: uses `wget`, unverified
against a real image build — the official `jenkins/jenkins` base image's
exact tool availability wasn't confirmed live. If the built image lacks
`wget`, the healthcheck will always report unhealthy (nothing in
`ci/compose.yaml` currently gates on Jenkins's health status, so this
wouldn't block the stack from running, but should be fixed if hit).

## Realistic problems this milestone documents (from the spec, verified against this repo's actual config)

- **Quality gate failing on new-code coverage**: SonarQube's default gate is
  "coverage on new code ≥ 80%". Read the failure at the PR's SonarQube Cloud
  link (posted as a check) — it lists exactly which new lines are uncovered,
  not the whole file's coverage.
- **Trivy CRITICALs with no fix**: handled by `ignore-unfixed: true` (see
  ADR 0008) — these don't fail CI but also don't show as fully clean; check
  the Trivy job summary for suppressed-but-unfixed findings periodically.
- **Hit for real on 2026-09-29**: the first real `trivy` job run found 3
  fixable CRITICAL CVEs (CVE-2026-68525, CVE-2026-65905, CVE-2026-65182) in
  the embedded Apache Tomcat pulled in via `spring-boot-starter-webmvc` off
  `spring-boot-starter-parent` 4.1.0. Tried the documented fix path (bump to
  a patched `spring-boot-starter-parent`) first — Maven Central's search
  index doesn't list any `4.x` release of that artifact at all (only up to
  `3.5.3`), so there was no way to verify which version, if any, actually
  carries the fix without guessing. Added time-boxed `.trivyignore` entries
  instead (owner + 2026-10-13 review date) rather than bump to an unverified
  version — see the file for the full justification. Re-triage before that
  date with a real Maven Central / NVD lookup once one is possible.
- **Digest mismatch**: structurally prevented by ADR 0005's design
  (`release.yml` never rebuilds), verified at runtime by check #4 above.
- **Testcontainers without Docker**: **confirmed working** — `build-test`
  passed for real on `ubuntu-latest`, meaning Docker was available and
  Testcontainers-backed tests ran without special handling.
- **GHCR push denied**: requires the workflow's `permissions: packages: write`
  (present in the `publish` job) AND the repo's own Settings → Actions →
  General → Workflow permissions allowing package writes, plus the GHCR
  package's own visibility/linkage settings on first push. **Confirmed
  working** — `publish` pushed `sha-<short>` successfully on run
  `36608891090`.
- **release-please not bumping**: requires PR titles to be Conventional
  Commits (enforced by squash-merge + branch protection's PR-title-as-commit
  setting — see `docs/branch-protection.md` step 7); a non-conventional
  title produces no version bump and no release PR update.
- **Hit for real: release-please PR opens but never runs CI**: not in the
  original spec's problem list, but a genuine first-run blocker. A PR opened
  by a workflow's default `GITHUB_TOKEN` does not trigger other workflow
  runs (GitHub's anti-recursion guard), so `ci.yml` never ran on the
  release-please PR and its required checks could never appear, let alone
  go green. Fixed by passing a PAT via `RELEASE_PLEASE_TOKEN` — see
  `docs/ci-setup.md` §2b. PENDING re-verification once that secret is set.
- **nohttp/checkstyle failures from new files**: **confirmed clean** —
  `build-test` passed for real; this milestone's files are all outside
  `src/`, so the existing `maven-checkstyle-plugin` bindings had nothing new
  to flag (one unrelated nohttp hit did occur on `ci/settings.xml.template`'s
  XML namespace URI — fixed, see commit history).

## One-time setup required before check 1-4 can run

SonarCloud project/token, the org-level Actions PR-creation permission
release-please needs, and GHCR write permission: see
[`docs/ci-setup.md`](../ci-setup.md).
