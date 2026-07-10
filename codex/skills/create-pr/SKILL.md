---
name: create-pr
description: Push a working branch, run project tests, create a GitHub pull request as Draft, post the Issue knowledge comment, and update Issue status labels when the project uses them. Use only when the user explicitly asks to push, create a PR, or open a pull request.
---

# Create PR

## Preconditions

- This workflow performs public remote actions (push, PR creation). Proceed only when the user explicitly requested it.
- Assumes the change is already committed (commit is handled by the `commit` skill). Run `$commit` first if it hasn't been.
- Target the project's default base branch (e.g. `main`, following the repo's convention), never a branch the project forbids merging into directly.

## Repository (dynamic)

Do not hardcode the repository. Resolve `{OWNER}/{REPO}` at runtime and read it as `$REPO` in every GitHub API call below:

```sh
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

GitHub API URLs take the form `https://api.github.com/repos/${REPO}/...`.

## Workflow

1. Confirm the Issue number from the prompt or URL. Ask if missing; do not guess.
2. Fetch Issue metadata with `gh` or the TLS fallback:

```sh
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}"
```

Use Issue assignees for the PR assignee. If the project runs a version-label scheme (e.g. MAJOR/MINOR/PATCH), carry the relevant label onto the PR.

3. Push only the current working branch:

```sh
git push -u origin "$(git branch --show-current)"
```

4. Run the project's test command and record the result. Detect it from the repo (e.g. `npm test`, `make test`, a containerized runner). If no runner is detectable or the environment cannot run it, record that and ask the user to run it manually. Running only the relevant tests is fine when the target is clear.

5. Create the PR as **Draft by default** (`--draft`). Only omit `--draft` when the user explicitly asked for a Ready (non-draft) PR. Body in Japanese. Use `.github/PULL_REQUEST_TEMPLATE.md` when present. TLS fallback: `curl -sk` against the GitHub API.

```sh
gh pr create \
  --draft \
  --title "PRタイトル" \
  --body 'PR本文' \
  --assignee "<issue assignee>" \
  --label "<project label scheme, if any>"
```

### PR Body Template

```markdown
## 対応したISSUE

* https://github.com/{OWNER}/{REPO}/issues/{ISSUE_NUMBER}

## 対応した分野

（該当するもののみ残し、それ以外は削除する）
- 機能追加
- 機能改善・拡張
- バグの修正
- リファクタリング
- その他

## 実装内容

（どのファイル/コードをどう変更したかを記載。変更の経緯は不要。）

## テスト方法

### 正常パターン

（実行したテストコマンドとその結果を記載。）

### エラーパターン

なし

## その他

なし
```

## Issue Knowledge Comment

After PR creation, update or create one integrated Issue comment marked with `<!-- codex-dev-log -->`, including the PR URL.

- Search existing comments for the marker (TLS fallback as above):

```sh
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/comments" \
  | jq '[.[] | select(.body | contains("<!-- codex-dev-log -->"))] | .[0] | {id, body}'
```

- Keep one "ナレッジ" section summarizing the whole Issue state from `git diff {base}...HEAD`; overwrite on each commit and always include the PR URL.
- Keep one folded "開発ログ" `<details>` table, appending a row per commit and emphasizing why the change was made.
- PATCH the marked comment if it exists; otherwise create it with `gh issue comment {ISSUE_NUMBER}` (TLS fallback: `curl -sk`).

## Issue Status Label (only if the project uses one)

If the project runs Issue status labels (e.g. an in-progress → in-review transition), update them; otherwise skip:

```sh
curl -sk -X DELETE -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/labels/{IN_PROGRESS_LABEL}"

curl -sk -X POST -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/labels" \
  -d '{"labels":["{REVIEW_LABEL}"]}'
```

## Result

Report the push result, test result, PR URL (state whether Draft or Ready), the Issue comment update, and the Issue-label outcome (if performed).
