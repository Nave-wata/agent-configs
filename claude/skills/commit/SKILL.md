---
name: commit
description: プロジェクトのコミットルールに準拠した git コミットを作成。「コミットして」「commit」「変更を保存」「git commit」など、コミット作成を依頼された時に自動で使用する。issue 番号は引数または会話文脈から取得し、未確定ならユーザーに確認する
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git switch:*), AskUserQuestion
argument-hint: <issue番号 or issue URL (optional)>
---

# コミット作成

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- git status: !`git status`
- 変更差分: !`git diff HEAD`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null`
- 最近のコミット: !`git log --oneline -10`

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

- **サマリ行（1行目）には「コードがどう変わったか」を書く**。「レビュー対応」「指摘修正」「修正」のような、何が変わったか分からないメッセージは禁止。レビュー起因の修正でも `[fix]: null 参照でクラッシュする問題を修正`、`[refactor]: 重複バリデーションを共通関数に集約` のように変更内容で表現する
  - 「レビューで指摘されたため」といった**経緯を残したい場合は本文の「変更の経緯」行や Issue のナレッジコメントに書く**（サマリ行には書かない）
- 詳細説明（変更の経緯/変更の内容）は簡単な変更の場合は省略可能
- HEREDOCを使用してコミットメッセージを渡すこと:
  ```bash
  git commit -m "$(cat <<'EOF'
  #123 [feat]: メッセージ
  EOF
  )"
  ```
- ファイルのステージは `git add -A` ではなく個別にファイル名を指定する
- 設計判断の理由や原因調査の経緯など、後から参照したい情報は本文の「変更の経緯」に書く

### 5. 結果報告

コミット完了後、`git status` で結果を確認し報告する。
