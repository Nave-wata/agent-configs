---
name: commit-pr
description: Commit, push a working branch, run project tests, create a GitHub pull request, post the Issue knowledge comment, and update Issue status labels when the project uses them. Use only when the user explicitly asks to push, create a PR, open a pull request, or run the full commit-and-PR workflow.
---

# Commit + PR

## Preconditions

- This workflow performs public remote actions (push, PR creation). Proceed only when the user explicitly requested it.
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
2. If on the base branch, inspect branch naming with `git branch -a` and create/switch to a working branch matching the repo's convention.
3. Fetch Issue metadata with `gh` or the TLS fallback:

```sh
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}"
```

Use Issue assignees for the PR assignee. If the project runs a version-label scheme (e.g. MAJOR/MINOR/PATCH), carry the relevant label onto the PR.

4. Commit using this format (stage files explicitly by path; never `git add -A` or stage secrets):

```text
#<issue番号> [<変更タイプ>]: <1行サマリ>

<変更の経緯>
<変更の内容>

Co-Authored-By: Codex <noreply@openai.com>
```

Change types: `feat`, `update`, `fix`, `refactor`, `test`, `chore`. Use a heredoc-style message.

The summary line (line 1) must state *how the code changed*. Never use vague messages like `レビュー対応`, `指摘修正`, or `修正` that don't say what changed — even for review-driven fixes, express the actual change (e.g. `[fix]: null 参照でクラッシュする問題を修正`, `[refactor]: 重複バリデーションを共通関数に集約`). If you want to record *why* the change was made (e.g. "raised in review"), put that in the `変更の経緯` body line or the Issue knowledge comment, not the summary line.

5. Push only the current working branch:

```sh
git push -u origin "$(git branch --show-current)"
```

6. Run the project's test command and record the result. Detect it from the repo (e.g. `npm test`, `make test`, a containerized runner). If no runner is detectable or the environment cannot run it, record that and ask the user to run it manually. Running only the relevant tests is fine when the target is clear.

7. Create the PR (body in Japanese). Use `.github/PULL_REQUEST_TEMPLATE.md` when present. TLS fallback: `curl -sk` against the GitHub API.

```sh
gh pr create \
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

Report the commit hash, push result, test result, PR URL, the Issue comment update, and the Issue-label outcome (if performed).
