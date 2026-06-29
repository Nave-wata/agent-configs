---
name: commit
description: プロジェクトのコミットルールに準拠した git コミットを作成。「コミットして」「commit」「変更を保存」「git commit」など、コミット作成を依頼された時に自動で使用する。issue 番号は引数または会話文脈から取得し、未確定ならユーザーに確認する
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git switch:*), Bash(gh issue comment:*), Bash(curl:*), AskUserQuestion
argument-hint: <issue番号 or issue URL (optional)>
---

# コミット作成

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- git status: !`git status`
- 変更差分: !`git diff HEAD`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null`
- 最近のコミット: !`git log --oneline -10`

## リポジトリの特定（汎用化）

このスキルは特定リポジトリに固定しない。GitHub API を呼ぶ際の `{OWNER}/{REPO}` は実行時に動的取得する:

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

以降の手順では `{OWNER}/{REPO}` をこの `$REPO` に読み替える。

## 実行手順

### 1. ブランチ確認

現在のブランチが main の場合、自動的に作業ブランチを作成して切り替える:

1. Issue番号を確認する（ステップ2を先行実施。未確定ならユーザーに確認）
2. `git branch -a` で既存ブランチの命名パターンを確認し、リポジトリの慣習に従ったブランチ名を決定する
3. `git switch -c {ブランチ名}` で新しいブランチを作成・切り替える
4. ユーザーにブランチ作成を報告し、続行する

### 2. Issue番号の確認

$ARGUMENTS から issue番号を抽出する（URLからの抽出も可）。引数がない場合や issue番号として解釈できない場合は、ユーザーに issue番号を確認すること。推測で進めないこと。

### 3. 変更の分析

git status と diff を確認し、以下を判断する:
- ステージすべきファイル（.env やクレデンシャルファイルは除外）
- 適切な変更タイプ
- コミットメッセージの内容

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

#### ルール

- 詳細説明（変更の経緯/変更の内容）は簡単な変更の場合は省略可能
- HEREDOCを使用してコミットメッセージを渡すこと:
  ```bash
  git commit -m "$(cat <<'EOF'
  #123 [feat]: メッセージ

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```
- ファイルのステージは `git add -A` ではなく個別にファイル名を指定する

### 5. Issueへのナレッジ投稿（統合コメント方式）

コミット完了後、対応するIssueにナレッジを投稿する。
**同一Issueに対するナレッジは1つのコメントに統合**する。

コメントの構成:
- **ナレッジ（メイン）**: Issue全体の変更を統合的に記述。コミットのたびに最新状態へ**上書き更新**する
- **開発ログ（付録）**: コミットごとの履歴表。`<details>` で折りたたみ、コミットのたびに行を**追記**する

#### 5-1. 既存コメントを検索

Issueのコメント一覧から `<!-- claude-dev-log -->` マーカーを含むコメントを検索する。

```bash
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/{OWNER}/{REPO}/issues/{ISSUE_NUMBER}/comments" \
  | jq '[.[] | select(.body | contains("<!-- claude-dev-log -->"))] | .[0] | {id, body}'
```

#### 5-2. ナレッジの作成・更新

ナレッジセクションは `git diff main...HEAD`（ベースブランチからの全体差分）を元に、統合的な内容を記述する。

##### 既存コメントがある場合 → PATCH で更新

ナレッジセクションを上書き更新し、開発ログ表に新しい行を追加する。

```bash
curl -sk -X PATCH -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/{OWNER}/{REPO}/issues/comments/{COMMENT_ID}" \
  -d '{"body": "更新後の本文"}'
```

##### 既存コメントがない場合 → 新規作成

```bash
gh issue comment {ISSUE_NUMBER} --body "$(cat <<'EOF'
<!-- claude-dev-log -->
## ナレッジ

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

#### 開発ログ（付録）の記載ルール

- **変更の理由・背景** が最も重要。「何を変えたか」よりも「なぜ変えたか」を重視する
- 簡単な変更でも理由・背景は省略しない（後から見た人が判断に迷わないようにするため）
- コミットメッセージの詳細説明と重複してもよい（Issueだけで完結できることを優先）

### 6. 結果報告

コミット完了後、`git status` で結果を確認し報告する。
