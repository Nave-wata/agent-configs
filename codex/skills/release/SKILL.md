---
name: release
description: Prepare a GitHub Release after a PR has been merged, including version calculation from version labels, release-note drafting, Issue comment consistency checks, and explicit user approval before release creation. Use only when the user explicitly asks to create or prepare a release.
---

# Release

## Preconditions

- This workflow creates or prepares a public GitHub Release. Do not run it unless explicitly requested.
- Require a PR number or URL. Ask if missing.
- Do not create the release until the user approves the computed version and release notes.

## Repository (dynamic)

Do not hardcode the repository. Resolve `{OWNER}/{REPO}` at runtime and read it as `$REPO` in every GitHub API call below:

```sh
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

GitHub API URLs take the form `https://api.github.com/repos/${REPO}/...` (TLS fallback: `curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)"`).

## Workflow

1. Fetch PR details, latest release, and PR commits:

```sh
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/pulls/{PR_NUMBER}"

curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/releases?per_page=1" | jq '.[0].tag_name'

curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/pulls/{PR_NUMBER}/commits" | jq '.[].commit.message'
```

2. Validate the PR is merged.
3. Validate the version bump. If the project uses version labels (e.g. MAJOR / MINOR / PATCH), require exactly one; if absent or questionable, ask the user.
4. Identify linked Issue(s), fetch PR files and Issue comments, and check whether the existing development knowledge comment still matches the final merged diff. Add a final Issue comment only when useful (TLS fallback applies).
5. Calculate the next semver tag:
   - MAJOR: `vX.0.0`
   - MINOR: `vX.Y+1.0`
   - PATCH: `vX.Y.Z+1`
6. Draft release notes in Japanese, with no emoji, grouped by actual change category. Use PR-level content, not raw commit lists. Omit empty categories. Add a Contributors section mentioning the PR author (`@username`), and wrap code/directive names in backticks. Category mapping (the Japanese labels are used verbatim as section headers — the English in brackets is explanatory only, never emitted): `feat`→新機能 [new features], `update`→改善 [improvements], `fix`→バグ修正 [bug fixes], `refactor`→リファクタリング [refactoring], `chore`→メンテナンス [maintenance], plus 破壊的変更 [breaking changes] for MAJOR.
7. Present the version and full release notes for approval. Do not create the release until approved.
8. After approval, create the release with the GitHub API (prefer `curl -sk`; `gh release create` can be unreliable in this environment):

```sh
curl -sk -X POST \
  -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/releases" \
  -d '{"tag_name":"vX.Y.Z","target_commitish":"{base}","name":"vX.Y.Z","body":"...","draft":false,"prerelease":false}'
```

(`target_commitish` = the project's default branch.)

## Output

Report the release URL, version, source PR, and any Issue comment update. If the project has release-triggered deployment, mention it starts; otherwise note that production deploy is handled outside Codex.

## Notes

- Avoid heredocs (sandbox write restrictions can break them).
- PR merge and release creation are separate instructions; do not chain them automatically.
- Verify the version label matches the actual change scope.
