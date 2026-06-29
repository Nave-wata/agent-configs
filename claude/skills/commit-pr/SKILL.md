---
name: commit-pr
description: コミット・プッシュ・PR作成・Issueラベル更新を一括実行。push と PR 作成という公開操作を伴うため、ユーザーが明示的に呼び出した時のみ実行する
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh:*), Bash(curl:*), AskUserQuestion
argument-hint: <issue番号 or issue URL>
---

# コミット + PR作成

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null`
- git status: !`git status`
- 変更差分: !`git diff HEAD`
- 最近のコミット: !`git log --oneline -10`

## リポジトリの特定（汎用化）

このスキルは特定リポジトリに固定しない。GitHub API を呼ぶ際の `{OWNER}/{REPO}` は実行時に動的取得する:

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
# gh が TLS エラー等で失敗する場合は origin リモートから抽出
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

以降の手順では `{OWNER}/{REPO}` をこの `$REPO` に読み替える。

## 実行手順

### 1. ブランチ確認

現在のブランチが main（または既定ブランチ）の場合、自動的に作業ブランチを作成して切り替える:

1. Issue番号を確認する（ステップ2を先行実施。未確定ならユーザーに確認）
2. `git branch -a` で既存ブランチの命名パターンを確認し、リポジトリの慣習に従ったブランチ名を決定する
3. `git switch -c {ブランチ名}` で新しいブランチを作成・切り替える
4. ユーザーにブランチ作成を報告し、続行する

### 2. Issue番号の確認

$ARGUMENTS から issue番号を抽出する（URLからの抽出も可）。引数がない場合や issue番号として解釈できない場合は、ユーザーに issue番号を確認すること。推測で進めないこと。

### 3. Issue情報の取得

Issue番号からGitHub APIで情報を取得する（`gh` コマンドがTLSエラーで失敗する場合は `curl -sk` を使用）:

```bash
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}"
```

取得する情報:
- アサイン（assignees）→ PRのアサインに使用
- ラベル → PRのラベルに使用（プロジェクトにバージョンラベル運用がある場合）

### 4. コミットの作成

以下のフォーマットでコミットを作成する:

```
#issue番号 [変更タイプ]: コミットメッセージ

変更の経緯
変更の内容

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

#### 変更タイプ

| タイプ | 用途 |
|--------|------|
| feat | 機能追加 |
| update | 既存機能の変更や強化 |
| fix | バグの修正 |
| refactor | 動作の変更なくリファクタリングのみ |
| test | テストコードの追加・修正のみ |
| chore | ライブラリの追加やgithub actionsの設定など |

#### コミットルール

- 詳細説明（変更の経緯/変更の内容）は簡単な変更の場合は省略可能
- HEREDOCを使用してコミットメッセージを渡すこと
- ファイルのステージは `git add -A` ではなく個別にファイル名を指定する
- .env やクレデンシャルファイルなど機密情報を含むファイルはコミットしないこと

### 5. プッシュ

リモートにプッシュする。上流ブランチが未設定の場合は `-u` フラグを付与する。

```bash
git push -u origin $(git branch --show-current)
```

### 6. テスト実行

プロジェクトのテストコマンドを実行し、結果を記録する。テストコマンドはプロジェクトごとに異なるため、リポジトリの構成から判断する（例: `npm test`、`composer test`、`docker compose exec <service> <test-runner>`、`make test` 等）。

- 検出できない／実行環境が無い場合は、その旨を記録し、ユーザーに手動実行を促す
- テスト対象が明確な場合は関連テストのみ実行してもよい

### 7. PR作成

以下のフォーマットでPRを作成する。PR本文は日本語。

```bash
gh pr create \
  --title "PRタイトル" \
  --body 'PR本文' \
  --assignee "issueのアサインと同じユーザー" \
  --label "プロジェクトのラベル運用に従う（あれば）"
```

`gh pr create` がTLSエラーで失敗する場合は `curl -sk` で GitHub API を直接呼び出す。

#### PR本文テンプレート

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

（コードベースでどこをどのように変更したのかを記載。変更の経緯は不要。複数項目可。）

## テスト方法

### 正常パターン

（実際にテストを実行した結果を記載。期待する動作のチェックのみ。複数項目可。）

### エラーパターン

なし

## その他

なし
```

#### PR本文の記載ルール

- **対応した分野**: 該当する分野のみ残し、関連しないものは削除する。追加は基本的にしない
- **実装内容**: 変更の経緯ではなく、どのファイル/コードをどう変更したかを記載
- **テスト方法 > 正常パターン**: 実行したテストコマンドとその結果を記載
- **テスト方法 > エラーパターン**: 検証中に発見した不具合がある場合のみ記載。基本は「なし」
- **その他**: レビュワーへの補足があれば記載。なければ「なし」

### 8. Issueへのナレッジ投稿（統合コメント方式）

PR作成後、対応するIssueにナレッジを投稿する。
**同一Issueに対するナレッジは1つのコメントに統合**する。PR URLも記載する。

コメントの構成:
- **ナレッジ（メイン）**: Issue全体の変更を統合的に記述。コミットのたびに最新状態へ**上書き更新**する
- **開発ログ（付録）**: コミットごとの履歴表。`<details>` で折りたたみ、コミットのたびに行を**追記**する

#### 8-1. 既存コメントを検索

Issueのコメント一覧から `<!-- claude-dev-log -->` マーカーを含むコメントを検索する。

```bash
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/comments" \
  | jq '[.[] | select(.body | contains("<!-- claude-dev-log -->"))] | .[0] | {id, body}'
```

#### 8-2. ナレッジの作成・更新

ナレッジセクションは `git diff {ベースブランチ}...HEAD`（ベースブランチからの全体差分）を元に、統合的な内容を記述する。

##### 既存コメントがある場合 → PATCH で更新

ナレッジセクションを上書き更新し、開発ログ表に新しい行を追加する。PR URLも更新する。

```bash
curl -sk -X PATCH -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/issues/comments/{COMMENT_ID}" \
  -d '{"body": "更新後の本文"}'
```

##### 既存コメントがない場合 → 新規作成

```bash
gh issue comment {ISSUE_NUMBER} --body "$(cat <<'EOF'
<!-- claude-dev-log -->
## ナレッジ

**PR**: {PR_URL}

（Issue全体の統合的な変更内容をここに記述）

---

<details>
<summary>開発ログ</summary>

| コミット | 種別 | 変更の理由・背景 | 変更の概要 |
|---------|------|----------------|-----------|
| `SHORT_HASH` | feat | 理由・背景の説明 | 変更概要の説明 |

</details>
EOF
)"
```

`gh issue comment` がTLSエラーで失敗する場合は `curl -sk` で GitHub API を直接呼び出す。

#### ナレッジセクションの記載ルール

- **何がどう変わったか**を俯瞰的に記述する（個々のコミット単位ではなく、Issue全体として）
- **設計判断の理由**、検討した代替案、注意点など、コミットログでは書ききれない内容を含める
- バグ修正の場合: 原因の特定経緯、再現条件、根本原因を記載し、ノウハウとして活用できるようにする
- コミットのたびに最新の全体像に上書き更新する（過去のナレッジ内容は開発ログで追える）
- PR URLを必ず含め、詳細な実装内容はPRで確認できるようにする

#### 開発ログ（付録）の記載ルール

- **変更の理由・背景** が最も重要。「何を変えたか」よりも「なぜ変えたか」を重視する
- 簡単な変更でも理由・背景は省略しない（後から見た人が判断に迷わないようにするため）
- コミットメッセージの詳細説明と重複してもよい（Issueだけで完結できることを優先）

### 9. Issueラベル更新（プロジェクトにステータスラベル運用がある場合）

プロジェクトが Issue のステータスラベル（例: `進行中` → `レビュー中`）を運用している場合は更新する。運用が無いリポジトリではこのステップをスキップする。

```bash
# 旧ステータスラベルを削除（例: 進行中）
curl -sk -X DELETE -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/labels/{IN_PROGRESS_LABEL}"

# 新ステータスラベルを追加（例: レビュー中）
curl -sk -X POST -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/labels" \
  -d '{"labels":["{REVIEW_LABEL}"]}'
```

### 10. 結果報告

以下を報告する:
- コミット内容
- テスト結果
- PR URL
- Issueラベルの更新結果（実施した場合）
