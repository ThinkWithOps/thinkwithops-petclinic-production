# ADR 0010: bump spring-boot-starter-parent from 4.1.0 to 4.1.1

Status: accepted (2026-10-13). Fix confirmed against Maven Central metadata; CI result recorded in `docs/validation/v2-cicd.md`.

## Problem and options

The `trivy` job (ADR 0008 policy: fixable CRITICAL fails the build) started failing on `main` on 2026-10-09, after Trivy's vulnerability database updated, with no change to dependencies. It reported `CVE-2026-47890` and `CVE-2026-47884` in `org.springframework:spring-webmvc` 7.0.8, both fixed in 7.0.9. The pipeline behaved as designed: a published fix exists, so the gate must fail.

Options considered:

1. Override only `spring-framework.version` to 7.0.9 in `pom.xml`. Smallest dependency change, but it moves one library off the combination the Spring Boot release was tested with.
2. Bump `spring-boot-starter-parent` to 4.1.1. Maven Central lists 4.1.1, and its `spring-boot-dependencies` pom manages `spring-framework.version` 7.0.9 (4.1.0 manages 7.0.8). The same bump also moves the managed Tomcat from 11.0.22 to 11.0.24.
3. Add `.trivyignore` entries. Rejected: a fix exists, and ignoring fixable CRITICALs removes the one rule ADR 0008 says has no exceptions.

## Decision

Option 2. One parent version change keeps every Spring library on the combination Spring Boot tested, and removes the need to track a separate override. `src/main` and `src/test` are not touched; this is a build-configuration change made for an operational reason (a failing security gate), as the repository rules allow. `scripts/check-static.py` pins the parent version as a guard on the layered-jar extraction in `docker/Dockerfile`; it is updated to 4.1.1 in the same commit.

## Trade-offs

`pom.xml` now differs from upstream (`build.gradle` upstream and in this repo still say 4.1.0; Gradle files are left untouched on purpose). A future merge from `upstream` will conflict on the parent version line and must be resolved deliberately, not by taking upstream's version.

The 4.1.1 upgrade also moves Tomcat (11.0.22 to 11.0.24). The three `.trivyignore` Tomcat entries were accepted because no patched parent could be verified at the time. Removing them on 2026-10-13 showed that 4.1.1 does not clear them: Trivy still reported `CVE-2026-68525`, `CVE-2026-65905` and `CVE-2026-65182` against `tomcat-embed-core` 11.0.24, fixed in 11.0.25. Maven Central lists 11.0.25 (and newer).

## Follow-up decision: override Tomcat

Because a fix exists, ignoring the CVEs again would break the ADR 0008 rule. `pom.xml` therefore sets `tomcat.version` to 11.0.25 (the lowest version Trivy names as fixed, so the change stays a single patch step), using the property Spring Boot documents for overriding a managed version. The property carries a comment saying when to remove it: once the parent manages 11.0.25 or newer. The `.trivyignore` file stays empty of suppressions.

## Enterprise scale

Enable Dependabot or Renovate for the parent version so patch releases arrive as PRs on a schedule, not only when a scanner fails. Add an alert on Trivy database-driven failures so a red `main` with no code change is routed to an owner the same day.
