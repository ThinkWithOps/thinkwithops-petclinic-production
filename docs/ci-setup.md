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
4. Make sure `pom.xml`'s `sonar.projectKey` property and `ci.yml`'s
   `-Dsonar.organization=` flag match what SonarCloud assigned — edit and
   commit if they don't (sonar-maven-plugin reads config from `pom.xml`
   properties / `-D` flags, not a `sonar-project.properties` file — that
   file only applies to the standalone `sonar-scanner` CLI, which this repo
   doesn't use).
5. Generate a token: My Account (top-right avatar) → Security → Generate
   Token. Copy it immediately — it's shown once.
6. In GitHub: repo → Settings → Secrets and variables → Actions → New
   repository secret → name `SONAR_TOKEN`, paste the token, Save.
7. Project → Administration → Analysis Method → turn **off** "Automatic
   Analysis." SonarCloud enables this by default on import and it scans on
   every push with no CI involved at all; running it alongside `ci.yml`'s
   CI-based analysis on the same project fails with "You are running CI
   analysis while Automatic Analysis is enabled." Keep CI-based only.

## 2. Let the release-please PR actually run CI

Two separate blockers here, both hit for real while building this milestone.

**2a. Allow GitHub Actions to open the PR at all.** `release.yml`'s
`release-please` job needs to open/update a pull request. This is denied by
default at the **organization** level for orgs, and the repo-level checkbox
stays greyed out until the org allows it.

1. If the repo is under a GitHub **organization**: go to
   `github.com/organizations/<org>/settings/actions` → Workflow permissions
   → check "Allow GitHub Actions to create and approve pull requests" →
   Save.
2. Then, repo → Settings → Actions → General → Workflow permissions → the
   same checkbox should now be clickable there too (some orgs inherit the
   org-level setting automatically and skip the repo toggle entirely).

**2b. Make that PR actually trigger `ci.yml`.** Even with 2a done, a PR
opened using the default `GITHUB_TOKEN` does **not** trigger other workflow
runs — this is GitHub's anti-recursion guard on workflow-authored events,
not a permission you can toggle. Hit this for real: the release-please PR
showed zero CI checks, and branch protection can never go green on a PR
with no checks at all. Fix: give `release-please-action` a personal access
token instead.

1. Create a PAT: your GitHub avatar → Settings → Developer settings →
   Personal access tokens → Fine-grained tokens → New token. Scope it to
   this repository only, with **Contents: Read and write** and
   **Pull requests: Read and write** permissions.
2. Repo → Settings → Secrets and variables → Actions → New repository
   secret → name `RELEASE_PLEASE_TOKEN`, paste the PAT, Save.
3. `release.yml` already passes `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}`
   to `release-please-action` — nothing else to change once the secret
   exists.

If you don't have access to create a PAT or the org's settings, this needs
an org owner or a bot/machine account with a PAT of its own.

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
