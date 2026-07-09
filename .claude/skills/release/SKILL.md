---
name: release
description: PRマージ後のリリース作成（バージョン算出・リリースノート生成・GitHub Release作成）。GitHub Release という公開操作のため、ユーザーが明示的に呼び出した時のみ実行する
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
argument-hint: <PR URL or PR number>
---

# リリース作成コマンド

ultrathink

<instructions>

## 概要

マージ済みPRの情報を元にセマンティックバージョニングに基づくGitHub Releaseを作成する。
ユーザーの承認を得てからリリースを作成すること。

## リポジトリの特定（汎用化）

このスキルは特定リポジトリに固定しない。GitHub API を呼ぶ際の `{OWNER}/{REPO}` は実行時に動的取得する:

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

以降の手順では `{OWNER}/{REPO}` をこの `$REPO` に読み替える。

## 実行手順

### 0. 引数チェック

$ARGUMENTS が空、または PR番号・PR URLとして解釈できない場合は、処理を中断しユーザーにPR番号またはPR URLの入力を求めること。推測や仮定で処理を進めないこと。

### 1. PR情報の取得

引数（$ARGUMENTS）からPR番号を抽出し、以下を並列取得する:

```bash
# PR詳細（タイトル、本文、ラベル、作者、マージ状態）
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/pulls/{PR_NUMBER}" \
  | jq '{title, body, labels: [.labels[].name], user: .user.login, merged}'

# 最新リリース
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/releases?per_page=1" \
  | jq '.[0].tag_name'

# PRのコミット一覧
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/pulls/{PR_NUMBER}/commits" \
  | jq '.[].commit.message'
```

### 2. バリデーション

- PRがマージ済みであることを確認
- PRにバージョンラベル（例: MAJOR / MINOR / PATCH）が付いていることを確認（プロジェクトのラベル運用に従う）
- ラベルがない場合や不適切な場合はユーザーに確認を取る

### 3. Issue記載内容の最終チェック

PRの本文からリンクされているIssue番号を特定し、以下を実施する。

#### 3-1. 情報の取得

```bash
# PRの最終差分（マージコミットの差分）
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/pulls/{PR_NUMBER}/files" \
  | jq '[.[] | {filename, status, changes, patch}]'

# Issueの既存コメント一覧
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}/comments" \
  | jq '[.[] | {id, user: .user.login, body}]'
```

#### 3-2. 整合性チェック

PRの最終差分とIssueのコメント内容を照合し、以下を確認する:

- 変更の理由・背景が実際の変更内容と整合しているか
- 開発途中のコミットコメントが最終成果物と齟齬がないか（レビュー対応やリファクタで変わった部分など）
- 記載漏れがないか

#### 3-3. 必要に応じた追記・修正

齟齬や不足がある場合、Issueに最終コメントを追記する:

```bash
gh issue comment {ISSUE_NUMBER} --body "$(cat <<'EOF'
## リリース前の最終確認

### 補足・修正事項

（開発途中のコメントと最終成果物の差異、追加の背景情報などを記載）
EOF
)"
```

`gh issue comment` がTLSエラーで失敗する場合は `curl -sk` で GitHub API を直接呼び出す。

齟齬や不足がない場合はこのステップをスキップする。

### 4. バージョン算出

現在の最新タグとPRラベルから次バージョンを算出:
- MAJOR: vX.0.0
- MINOR: vX.Y+1.0
- PATCH: vX.Y.Z+1

### 5. リリースノート生成

PRラベルに応じたテンプレートでリリースノートを生成する。

#### リリースノートのルール

- 絵文字を使用しない
- OSSスタイルで変更内容を分かりやすく記載する
- **変更の粒度はPR単位**とする。個々のコミットメッセージをそのまま列挙しない
  - ブランチ内での修正・リファクタ・レビュー対応等のコミットは、最終的なPRの成果物として統合して記述する
  - コミット履歴はカテゴリ判定の参考にのみ使い、リリースノートの項目はPRのタイトル・本文・実際の変更内容から構成する
- 該当する変更がないカテゴリは省略する（空のカテゴリ枠は不要）
- 変更内容や経緯が不明瞭な場合はユーザーに確認を取る
- Contributorsセクションを追加し、PRの作者をメンション形式（`@username`）で記載する
- コード名やディレクティブ名はバッククォートで囲み、メンションとして認識されないようにする

#### カテゴリ対応表

PRタイトルのプレフィックスまたはコミットメッセージのプレフィックスからカテゴリを判定する:

| コミットプレフィックス | カテゴリ名 |
|----------------------|-----------|
| feat | 新機能 |
| update | 改善 |
| fix | バグ修正 |
| refactor | リファクタリング |
| chore | メンテナンス |
| - | 破壊的変更（MAJOR時） |

#### PATCH リリース（簡潔版）

```markdown
## 変更内容

### バグ修正
- バグ修正の説明 (#PR番号)

### 改善
- 改善内容の説明 (#PR番号)

## Contributors
@username

**Full Changelog**: https://github.com/{OWNER}/{REPO}/compare/v前バージョン...v現バージョン
```

#### MINOR / MAJOR リリース（詳細版）

```markdown
## 変更内容

### 新機能
- **機能名** (#PR番号)

  機能の概要と目的を1-2文で説明。

### 破壊的変更
- **変更概要** (#PR番号)

  変更内容と移行方法を説明。

### 改善
- **改善概要** (#PR番号)
  改善の背景と効果を説明。

## Contributors
@username

**Full Changelog**: https://github.com/{OWNER}/{REPO}/compare/v前バージョン...v現バージョン
```

### 6. ユーザー承認

以下を提示してユーザーの承認を得る:
- バージョン番号
- リリースノート全文

**承認を得るまでリリースを作成しないこと。**

### 7. リリース作成

承認後、GitHub APIでリリースを作成する。

**重要: `gh release create` はTLSエラーが発生することがあるため、必要に応じて `curl -sk` を使用すること。**

```bash
curl -sk -X POST \
  -H "Authorization: token $(gh auth token 2>/dev/null)" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${REPO}/releases" \
  -d '{
    "tag_name": "vX.Y.Z",
    "target_commitish": "main",
    "name": "vX.Y.Z",
    "body": "リリースノート本文",
    "draft": false,
    "prerelease": false
  }'
```

### 8. 完了報告

リリースURLを提示する。プロジェクトにリリース連動の自動デプロイがある場合は、それが開始される旨も伝える。

</instructions>

## 注意事項

- HEREDOCを使用しないこと（サンドボックス環境の書き込み制限で失敗することがある）
- PRマージとリリース作成は別々の指示で行う（自動的に連続しない）
- ラベルが実際の変更内容に対して適切か必ず検証する
