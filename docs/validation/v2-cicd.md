# V2 validation: CI/CD pipeline

Status: **PARTIALLY VERIFIED** (updated 2026-10-01). `ci.yml` has run for
real on push to `main` (run `36608891090`) with `build-test`, `quality-gate`,
`image`, `trivy`, `config-scan`, and `publish` all green — reached only
after fixing several real, first-run-only bugs along the way (see the
commit history and the "Hit for real" notes below). Release digest promotion is now
verified (check 4); the Jenkins/Nexus path is still not runtime-verified — see
check 5.

## Required checks and how to produce them

| # | Scenario | How to trigger | Status |
|---|---|---|---|
| 1 | PR with a failing test is blocked | Push a commit that breaks a test, open a PR | Not yet deliberately tested; `build-test` itself is confirmed working (green on real runs) |
| 2 | A CRITICAL vulnerability blocks the pipeline | (Happened organically, not via a deliberately added test dependency) | **Verified for real**: the first real `trivy` run found 3 genuine fixable-CRITICAL Tomcat CVEs and failed the job exactly as designed — see the "Hit for real" note below |
| 3 | A push to `main` goes fully green | Push to `main` | **Verified**: run `36608891090`, all 6 jobs green. PR-merge-specific gating (branch protection required checks) not yet separately confirmed — depends on `docs/branch-protection.md` being applied |
| 4 | Release promotes the same digest | Merge a `feat:`/`fix:` commit, let release-please open its PR, merge it | **Verified for real** (2026-10-01): release `petclinic-v1.1.0` (PR #7), Release run `36888363516`; `promote-by-digest` logged source and promoted digest both `sha256:bd013a5d24c58e1435a0c1ec626d0fdfae635de916fc9346f9bc066719f95f45` and `Digest equality proven: same image, no rebuild.` Releases 1.0.0 and 1.0.2 stayed incomplete (see notes below) |
| 5 | Jenkins pipeline runs green locally and a JAR appears in Nexus | `./scripts/ci-stack-up.sh`, complete the printed first-run steps, trigger the `petclinic-ci` Jenkins job | **Implementation prepared; runtime verification pending a real Docker engine run.** Not run yet — needs a real Docker engine. See the Jenkins notes below |

### Jenkins/Nexus path: what is and isn't known

Nothing here has been executed. The pipeline path
`prepare -> verify -> sonar -> quality gate -> image build -> Trivy ->
Checkov + ShellCheck -> SBOM -> Nexus` must run end to end on a real Docker
engine before this check can be marked verified. Static checks only so far
(`docker compose config`, `bash -n`, YAML parse — these prove syntax, not behavior). Findings from reviewing the
path before the first run. Static fixes are prepared in the files; none has been
runtime-verified (plugin resolution, Jenkins startup, JCasC load, healthchecks,
Testcontainers, the Sonar webhook and the Nexus deployment are all unrun):

- **Plugin pins** (also `--latest=false` so transitive dependencies are not
  upgraded past the pinned core): several pins in `ci/jenkins/plugins.txt` did not exist on
  the Jenkins mirror (`credentials-binding`, `docker-workflow`,
  `configuration-as-code`, `junit`, `sonar`), which would have failed the image
  build. Replaced with real, era-matched versions; `job-dsl` was missing but is
  required by the `jobs:` block in `ci/jenkins/casc.yaml`.
- **Admin credentials**: `JENKINS_ADMIN_USER/PASSWORD` were read by
  `casc.yaml` but never passed into the container.
- **Tools**: the Jenkins image lacked the Docker CLI/Compose/Buildx, Trivy,
  Checkov and ShellCheck that the `Jenkinsfile` calls.
- **Docker socket**: mounted but unusable without the host socket's group ID
  (`DOCKER_GID`, `group_add`).
- **SonarQube server**: the `local-sonarqube` installation the `Jenkinsfile`
  names was not configured; the SonarQube webhook that `waitForQualityGate`
  needs was undocumented.
- **Healthchecks**: Jenkins, SonarQube and Nexus checks used `wget`. The
  SonarQube image (per its upstream Dockerfile) ships `curl` and no `wget`, and
  the Nexus image is UBI-minimal (no `wget`). All three now use `curl`. The
  tool presence in the *pinned* images was inferred from upstream Dockerfiles,
  not from running them — confirm on a real Docker host.
- **Nexus publish**: the stage previously ran `mvn deploy -DskipTests`, which
  re-packaged a JAR that was never tested. It now deploys the verify-stage JAR
  after a checksum check.
- **`SHORT_SHA`**: the top-level `env.GIT_COMMIT.take(12)` is not guaranteed to
  exist before checkout; it is now computed in an early `prepare` stage.
- **Redeploys**: Nexus' default `maven-releases` policy rejects re-uploading the
  same version, so re-running the pipeline after a successful publish fails the
  last stage until the version changes or redeploy is allowed on that repo.
- **Test databases from inside Jenkins**: `mvnw verify` runs in the Jenkins
  container but starts databases on the host daemon. `PostgresIntegrationTests`
  uses Spring Boot's Docker Compose support (`docker-compose.yml`, published
  port 5432) and `MySqlIntegrationTests` uses Testcontainers; with a unix socket
  both would resolve the host as `localhost`, i.e. the Jenkins container itself.
  Prepared: `extra_hosts: host.docker.internal:host-gateway`,
  `SPRING_DOCKER_COMPOSE_HOST` and `TESTCONTAINERS_HOST_OVERRIDE` on the Jenkins
  service; no test is skipped or changed. Unverified until the `verify` stage
  runs. Port 5432 must also be free on the host.

The required SonarQube webhook is printed by `scripts/ci-stack-up.sh`.

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
- **Hit for real: release-please PR opens but never runs CI**: a PR opened
  by a workflow's default `GITHUB_TOKEN` does not trigger other workflow
  runs (GitHub's anti-recursion guard), so `ci.yml` never ran on the
  release-please PR and its required checks could never appear, let alone
  go green. **Fixed**: passing a PAT via `RELEASE_PLEASE_TOKEN` to
  `release-please-action` — see `docs/ci-setup.md` §2b. Confirmed working:
  PR #1's checks all ran and passed once the secret was set.
- **Hit for real: `petclinic-v1.0.0`'s image was never promoted**. PR #1
  (`chore(main): release petclinic 1.0.0`) was merged via the GitHub web UI,
  but its merge commit (`562eff88`) shows **zero check-runs at all**
  (`gh api .../commits/562eff88.../check-runs` → `total_count: 0`) — the
  push event that should have triggered `ci.yml`/`release.yml` never turned
  into a workflow run. release-please's own job still ran independently
  (triggered by a later, unrelated push) and correctly created the GitHub
  Release + tag `petclinic-v1.0.0`, but `promote-by-digest` then failed with
  `manifest unknown`: there was no `sha-562eff884f71` image in GHCR to
  promote, because `publish` never ran on that commit. This specific release
  is permanently incomplete (its image was never built/scanned, so there is
  nothing to promote by digest — building one now from current `main` would
  not be "the same tested image," defeating the entire point of this
  design). Added `workflow_dispatch` to both workflows as a recovery path
  for a future occurrence (can't fix this specific past commit — GitHub
  `workflow_dispatch` only runs against a branch/tag ref, not an arbitrary
  historical SHA). Confirmed the underlying push-trigger works normally on
  every push before and after this one incident — treating it as a one-off,
  not a systemic issue, unless it recurs.
- **Hit for real (the actual root cause, 100% reproducible, not a one-off):
  `release.yml` on `push: branches: [main]` runs concurrently with
  `ci.yml`, not after it.** `promote-by-digest` failed with
  `manifest unknown` on every push-triggered `Release` run tested (three in
  a row), always within ~30 seconds, because `ci.yml`'s `publish` job takes
  5-6 minutes and hadn't pushed the `sha-<short>` image yet. **Fixed**:
  changed `release.yml`'s trigger to
  `workflow_run: workflows: [CI], types: [completed], branches: [main]`,
  gated on `github.event.workflow_run.conclusion == 'success'` — this makes
  `release.yml` wait for `ci.yml` to fully finish, and only proceed if it
  passed, before starting at all. **Confirmed**: every Release run since
  succeeds in ~15-40s, and a cancelled duplicate CI run correctly produces a
  skipped Release run instead of a failure.
- **Hit for real: release 1.0.2 merged but was never tagged or promoted.**
  PR #4 (`chore(main): release petclinic 1.0.2`) carries the label
  `autorelease: snapshot`, not `autorelease: pending`. It began as the
  post-1.0.1 SNAPSHOT bump PR (#2's successor) opened before `skip-snapshot`
  was enabled; release-please then reused the same branch and rewrote it as
  a normal release PR but left the stale label. release-please only turns
  `pending` PRs into releases, so the run on the merge logged
  `looking for tagName: petclinic-v1.0.2`, created nothing, and
  `promote-by-digest` was skipped. No `petclinic-v1.0.2` tag or GitHub
  Release exists. The next release PR (#5, 1.1.0) was labeled `pending`
  correctly, which confirms this was a one-off from the config change
  mid-cycle, not a systemic bug. **Confirmed**: merging a `fix:` PR (#6)
  opened release PR #7 labeled `pending`, and merging it created
  `petclinic-v1.1.0` and ran `promote-by-digest` successfully (check 4). No
  SNAPSHOT PR appeared (`skip-snapshot` works). `petclinic-v1.0.2` was never
  created and will not be backfilled.
- **Cosmetic**: release-please logs `Unable to parse release name:
  v1-containerized — Containerized PetClinic` because that draft GitHub
  Release has a non-semver name. Harmless.
- **nohttp/checkstyle failures from new files**: **confirmed clean** —
  `build-test` passed for real; this milestone's files are all outside
  `src/`, so the existing `maven-checkstyle-plugin` bindings had nothing new
  to flag (one unrelated nohttp hit did occur on `ci/settings.xml.template`'s
  XML namespace URI — fixed, see commit history).

## One-time setup required before check 1-4 can run

SonarCloud project/token, the org-level Actions PR-creation permission
release-please needs, and GHCR write permission: see
[`docs/ci-setup.md`](../ci-setup.md).
