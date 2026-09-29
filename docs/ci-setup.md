# One-time CI/CD setup (repo/org settings, not versionable as code)

Everything below is a GitHub/SonarCloud UI setting, not a file in this repo —
do these once per fork/clone that wants working CI, in this order. Discovered
by running the pipeline for real and fixing what it hit; see the ADRs in
`docs/adr/` for the design reasoning, this file is just the checklist.

## 1. SonarCloud project

1. Sign in to [sonarcloud.io](https://sonarcloud.io) with GitHub.
2. Import your GitHub organization/account as a SonarCloud organization (or
   use an existing one) — **don't** enable "Automatically import new GitHub
   repositories" unless you actually want every repo in that org scanned;
   import just this one manually.
3. Import this repository as a SonarCloud project. Note the **Organization
   Key** and **Project Key** it assigns (Project → Administration →
   Information, or the org's own settings page).
4. Make sure `sonar-project.properties` at the repo root has matching
   `sonar.organization` / `sonar.projectKey` values — edit and commit if
   SonarCloud assigned different ones than what's currently there.
5. Generate a token: My Account (top-right avatar) → Security → Generate
   Token. Copy it immediately — it's shown once.
6. In GitHub: repo → Settings → Secrets and variables → Actions → New
   repository secret → name `SONAR_TOKEN`, paste the token, Save.

## 2. Allow GitHub Actions to open the release-please PR

`release.yml`'s `release-please` job needs to open/update a pull request
using the workflow's own `GITHUB_TOKEN`. This is denied by default at the
**organization** level for orgs, and the repo-level checkbox stays greyed
out until the org allows it.

1. If the repo is under a GitHub **organization**: go to
   `github.com/organizations/<org>/settings/actions` → Workflow permissions
   → check "Allow GitHub Actions to create and approve pull requests" →
   Save.
2. Then, repo → Settings → Actions → General → Workflow permissions → the
   same checkbox should now be clickable there too (some orgs inherit the
   org-level setting automatically and skip the repo toggle entirely).
3. If you don't have access to the organization's settings, this step needs
   an org owner — there's no repo-level workaround that doesn't involve a
   personal access token (worse security posture; not used here).

## 3. GHCR (container registry) push permission

`ci.yml`'s `publish` job pushes to `ghcr.io/<owner>/<repo>` using
`GITHUB_TOKEN`. Repo → Settings → Actions → General → Workflow permissions
→ "Read and write permissions" must be selected (this also covers the SARIF
upload / code-scanning write the `trivy` and `config-scan` jobs need).

## 4. Branch protection

See [`docs/branch-protection.md`](branch-protection.md) — required checks,
squash-merge-only, PR title as the squash commit message (release-please
needs Conventional Commit PR titles to version correctly).

## Known gotcha already fixed in this repo, for context

GHCR requires an all-lowercase repository path. `github.repository` in a
GitHub Actions expression preserves the org's actual casing (e.g. an
uppercase org name), which Docker rejects with `repository name must be
lowercase`. Both `ci.yml` and `release.yml` normalize this via a
`tr '[:upper:]' '[:lower:]'` step before building any image tag — nothing
for you to configure here, just why that step exists if you're reading the
workflow files.
