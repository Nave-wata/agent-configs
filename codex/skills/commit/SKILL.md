---
name: commit
description: Create a git commit following the repository's Issue-number, branch, staging, message, and knowledge-comment rules. Use when the user asks to commit, save changes, run git commit, or prepare a repository-rule-compliant commit. The Issue number comes from the argument or conversation context; if unresolved, ask the user.
---

# Commit

## Repository (dynamic)

Do not hardcode the repository. Resolve `{OWNER}/{REPO}` at runtime and read it as `$REPO` in every GitHub API call below:

```sh
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

GitHub API URLs take the form `https://api.github.com/repos/${REPO}/...`.

## Workflow

1. Inspect `git status --short`, `git branch --show-current`, `git diff HEAD`, and recent commits.
2. If on the project's default base branch (e.g. `main`, following the repo's convention), determine the Issue number first, inspect branch naming with `git branch -a`, then create a working branch matching the repo's convention. Never commit directly to the base branch.
3. Extract the Issue number from the prompt or URL. If it is missing or ambiguous, ask the user; do not guess.
4. Analyze the diff and choose the change type: `feat`, `update`, `fix`, `refactor`, `test`, or `chore`.
5. Stage files explicitly by path. Never use `git add -A` or stage `.env`, keys, credentials, generated secrets, or unrelated user changes.
6. Commit with this format:

```text
#<issue番号> [<変更タイプ>]: <1行サマリ>

<変更の経緯>
<変更の内容>

Co-Authored-By: Codex <noreply@openai.com>
```

Use a heredoc-style message when invoking `git commit`. The detail body may be omitted for trivial changes.

## Issue Knowledge Comment

After committing, update or create one integrated Issue comment marked with `<!-- codex-dev-log -->`.

- Search existing comments for the marker. If `gh` hits the known TLS error, use `curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)"`:

```sh
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/comments" \
  | jq '[.[] | select(.body | contains("<!-- codex-dev-log -->"))] | .[0] | {id, body}'
```

- Keep one "ナレッジ" section that summarizes the whole Issue state from `git diff {base}...HEAD` and overwrite it on each commit. Capture design rationale, alternatives considered, and root-cause notes for bug fixes.
- Keep one folded "開発ログ" `<details>` table and append a row per commit, emphasizing why the change was made.
- If a marked comment exists, PATCH it; otherwise create a new one with `gh issue comment {ISSUE_NUMBER}` (TLS fallback: `curl -sk` against the API).

## Result

Run `git status --short` and report the commit hash, staged/unstaged remainder, and any Issue comment update result.
