---
name: review
description: 現在の変更（git diff）をコードレビューし、Critical / Important / Suggestions に分類して報告する。「レビューして」「コードをチェック」「変更点を確認」などレビューを依頼された時に使用する。読み取り専用で副作用がない
---

# Review（opencode 単体）

opencode 単体でコードレビューを行う。Claude Code 版の `review` は pr-review-toolkit サブエージェントや Codex MCP を並列実行するが、opencode にはそれらの機構が無いため、**opencode 自身が diff を直接レビューする**。

## リポジトリの特定

GitHub API を呼ぶ場合の `{OWNER}/{REPO}` は実行時に動的取得する:

```sh
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

## 手順

1. レビュー対象の差分を把握する。
   - 現在のブランチ・`git status --short`・差分を確認する
   - 既定はフィーチャーブランチなら `main...HEAD`（分岐点 `git merge-base main HEAD` から）、main 上なら `HEAD~1`
   - 未コミットの作業ツリー変更も対象に含める
   - 対象が曖昧な場合はユーザーに確認してから進める
2. 以下の観点でレビューする（プロジェクトの言語・フレームワークに合わせて適用）:
   - バグ・挙動の退行、境界条件、エラーハンドリングの欠落
   - 認証・認可、入力検証、SQL/クエリのスコープと安全性
   - 外部 API・ストレージ・キャッシュ等の副作用
   - 機密情報の漏洩、危険なコマンド、本番/保護ブランチへの直接変更
   - 言語・フレームワークの互換性
   - 追加・変更に対する検証（テスト）の不足
3. 指摘を重要度で分類する:
   - **Critical**: PR / マージ前に必ず修正
   - **Important**: 意図的に許容する場合を除き修正推奨
   - **Suggestions**: 任意の改善
4. 指摘を重要度順に**先頭**に置いて報告する。可能な限り `file:line` を付す。問題が無ければその旨と、残っている検証ギャップ（未テスト箇所など）を述べる。

## 注意

- このスキルは**読み取り専用**。修正やコミットは行わない。修正が必要な場合はユーザーの指示を仰ぐ。
