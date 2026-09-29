# Branch protection (repo settings, documented as steps)

GitHub branch protection is a repository setting, not a file this repo can
version — these are the exact steps to reproduce it. Apply to `main`.

1. Repo Settings → Branches → Add branch protection rule → Branch name pattern: `main`.
2. Enable **Require a pull request before merging**.
   - Require approvals: at least 1.
3. Enable **Require status checks to pass before merging**.
   - Enable **Require branches to be up to date before merging**.
   - Required checks (must match the job names in `.github/workflows/ci.yml`
     exactly, so add them after the workflow has run at least once so GitHub
     can list them):
     - `build-test`
     - `quality-gate`
     - `trivy`
     - `config-scan`
4. Enable **Require conversation resolution before merging**.
5. Enable **Do not allow bypassing the above settings** (applies rules to
   admins too — otherwise the rule set is advisory, not enforced).
6. Leave **Allow force pushes** and **Allow deletions** disabled (default).
7. Squash-merge only: repo Settings → General → Pull Requests →
   uncheck "Allow merge commits" and "Allow rebase merging", leave
   "Allow squash merging" checked, and set the default squash commit message
   to "Pull request title" so release-please's Conventional Commit parsing
   sees the enforced PR title, not an arbitrary merge commit message.

`publish` and the `release-please`/`promote-by-digest` jobs are intentionally
**not** required PR checks — they only run on push to `main` (after merge)
or on release creation, so they can never gate a PR.
