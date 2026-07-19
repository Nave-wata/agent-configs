---
name: create-pr
description: コミット済みの変更を push し、GitHub PR を Draft で作成。Issueラベル更新まで一括実行。push と PR 作成という公開操作を伴うため、ユーザーが明示的に呼び出した時のみ実行する
disable-model-invocation: true
allowed-tools: Bash(git push:*), Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(gh:*), Bash(curl:*), AskUserQuestion
argument-hint: <issue番号 or issue URL>
---

# PR作成

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null`
- git status: !`git status`
- 最近のコミット: !`git log --oneline -10`

## リポジトリの特定（汎用化）

このスキルは特定リポジトリに固定しない。GitHub API を呼ぶ際の `{OWNER}/{REPO}` は実行時に動的取得する:

```bash
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
# gh が TLS エラー等で失敗する場合は origin リモートから抽出
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

以降の手順では `{OWNER}/{REPO}` をこの `$REPO` に読み替える。

このスキルはコミット済みの変更を前提とする（コミットは `commit` スキルが担当）。

## 実行手順

### 1. Issue番号の確認

$ARGUMENTS から issue番号を抽出する（URLからの抽出も可）。引数がない場合や issue番号として解釈できない場合は、ユーザーに issue番号を確認すること。推測で進めないこと。

### 2. Issue情報の取得

Issue番号からGitHub APIで情報を取得する（`gh` コマンドがTLSエラーで失敗する場合は `curl -sk` を使用）:

```bash
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" \
  "https://api.github.com/repos/${REPO}/issues/{ISSUE_NUMBER}"
```

取得する情報:
- アサイン（assignees）→ PRのアサインに使用
- ラベル → PRのラベルに使用（プロジェクトにバージョンラベル運用がある場合）

### 3. プッシュ

リモートにプッシュする。上流ブランチが未設定の場合は `-u` フラグを付与する。

```bash
git push -u origin $(git branch --show-current)
```

### 4. PR作成

**デフォルトで Draft PR として作成する**（`--draft` を付与）。ユーザーから明示的に Ready（非Draft）での作成を指示された場合のみ `--draft` を外す。

PR本文は日本語。

```bash
gh pr create \
  --draft \
  --title "PRタイトル" \
  --body 'PR本文' \
  --assignee "issueのアサインと同じユーザー" \
  --label "プロジェクトのラベル運用に従う（あれば）"
```

`gh pr create` がTLSエラーで失敗する場合は `curl -sk` で GitHub API を直接呼び出す。

#### PRテンプレートの解決

プロジェクト自身の PR テンプレートを探し、**あればそちらを主として使う**:

1. `.github/PULL_REQUEST_TEMPLATE.md`（小文字の `pull_request_template.md` も確認）、リポジトリルート直下、`docs/` 配下、`.github/PULL_REQUEST_TEMPLATE/` ディレクトリ（複数テンプレート運用）の順に探す
2. 見つかった場合: そのテンプレートの構成・見出しに従って本文を書く（下記のデフォルトテンプレートは使わない）
3. 見つからない場合: 下記のデフォルトテンプレートを使う

いずれの場合も、後述の「判断を仰ぎたい点」セクションを必ず含める。

#### PR本文テンプレート（プロジェクトにテンプレートが無い場合のデフォルト）

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

## 判断を仰ぎたい点

なし

## その他

なし
```

#### PR本文の記載ルール

- **対応した分野**: 該当する分野のみ残し、関連しないものは削除する。追加は基本的にしない
- **実装内容**: 変更の経緯ではなく、どのファイル/コードをどう変更したかを記載
- **テスト方法 > 正常パターン**: 開発中に実施した動作確認・テストの内容と結果を記載
- **テスト方法 > エラーパターン**: 検証中に発見した不具合がある場合のみ記載。基本は「なし」
- **その他**: レビュワーへの補足があれば記載。なければ「なし」

#### 「判断を仰ぎたい点」セクション

プロジェクトテンプレートの有無に関わらず、「その他」「備考」などの任意事項セクションの**直前**に `## 判断を仰ぎたい点` を挿入する（任意事項セクションが無いテンプレートでは末尾に置く）。

目的: レビュワーに「一通りの確認」を丸投げせず、実装者だけでは閉じられない判断だけを渡す。

- 記載するのは次の2種類に限る:
  - 実装者（と AI レビュー）では**判断がつかない**論点（組織固有の優先順位、スコープ、許容リスクなど権限や文脈が必要なもの）
  - 自分なりの結論は出したが、**自分だけの判断では不安が残る**箇所
- 各項目は「何について」「なぜ自分で判断を閉じられないのか」「自分としてはどう考えるか（選択肢と推し案）」をセットで書き、レビュワーが意思決定だけを返せる形にする
- 「全体的に確認お願いします」「気になる点があればご指摘ください」のような丸投げは書かない
- 自分で確認・判断を閉じられた事項はここに書かない（実装内容・テスト方法に結果として書く）
- 無ければ「なし」（Approve 以外にやることが無い PR が理想）

### 5. Issueラベル更新（プロジェクトにステータスラベル運用がある場合）

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

### 6. 結果報告

以下を報告する:
- プッシュ結果
- PR URL（Draft か Ready かを明記）
- 「判断を仰ぎたい点」に記載した内容（あれば）
- Issueラベルの更新結果（実施した場合）
