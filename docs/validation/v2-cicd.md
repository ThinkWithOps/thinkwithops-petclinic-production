# V2 validation: CI/CD pipeline

Status: **PENDING RUNTIME VERIFICATION**. Files are complete and statically
reviewed; the checks below require a real GitHub repository connected to
GitHub Actions, SonarQube Cloud, and a real Docker engine for the Jenkins
stack. None of this has been run yet — do not treat this document as proof
until each row below is filled in with a real result.

## Required checks and how to produce them

| # | Scenario | How to trigger | Expected result |
|---|---|---|---|
| 1 | PR with a failing test is blocked | Push a commit that breaks a test, open a PR | `build-test` check fails red; PR merge button disabled (branch protection) |
| 2 | PR introducing a known-vulnerable dependency is blocked | Add a dependency with a known unfixed-but-available-patch CRITICAL CVE | `trivy` check fails red; SARIF findings visible under Security → Code scanning |
| 3 | A green PR merges | Open a PR with passing tests, clean Sonar gate, clean Trivy/Checkov | All 4 required checks green; merge allowed; squash-merge produces one commit on `main` |
| 4 | Release promotes the same digest | Merge a `feat:`/`fix:` commit, let release-please open its PR, merge it | `promote-by-digest` job log shows "Digest equality proven"; `docker buildx imagetools inspect ghcr.io/<repo>:petclinic-vX.Y.Z` and `ghcr.io/<repo>:sha-<short>` report the same manifest digest |
| 5 | Jenkins pipeline runs green locally and a JAR appears in Nexus | `./scripts/ci-stack-up.sh`, complete the printed first-run steps, trigger the `petclinic-ci` Jenkins job | Jenkinsfile stages all green; JAR visible in Nexus's `maven-releases` repository browse UI |

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
- **Testcontainers without Docker**: `ubuntu-latest` GitHub runners ship
  Docker preinstalled and running, so this is expected to work unmodified;
  PENDING confirmation from a real run (check #1-3's runner logs will show
  whether Testcontainers-backed tests in `src/test` actually execute vs.
  skip).
- **GHCR push denied**: requires the workflow's `permissions: packages: write`
  (present in the `publish` job) AND the repo's own Settings → Actions →
  General → Workflow permissions allowing package writes, plus the GHCR
  package's own visibility/linkage settings on first push.
- **release-please not bumping**: requires PR titles to be Conventional
  Commits (enforced by squash-merge + branch protection's PR-title-as-commit
  setting — see `docs/branch-protection.md` step 7); a non-conventional
  title produces no version bump and no release PR update.
- **nohttp/checkstyle failures from new files**: `mvnw verify` runs the
  existing `maven-checkstyle-plugin` bindings (nohttp + checkstyle) already
  configured in `pom.xml` — any new file this milestone adds under `src/`
  would trip it, but this milestone adds no files under `src/`, only CI/docs
  configuration, so none is expected; PENDING confirmation on first real run.

## One-time setup required before check 1-4 can run

SonarCloud project/token, the org-level Actions PR-creation permission
release-please needs, and GHCR write permission: see
[`docs/ci-setup.md`](../ci-setup.md).
