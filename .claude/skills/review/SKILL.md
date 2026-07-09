---
name: review
description: PR総合レビュー（pr-review-toolkit + Codex MCP を並列実行し結果を統合）。「レビューして」「PR をレビュー」「コードをチェック」「変更点を確認」など、コードレビューを依頼された時に自動で使用する。読み取り専用で副作用がないため自律発火を許可
allowed-tools: Bash(git:*), Bash(gh:*), Bash(curl:*), Read, Glob, Grep, Agent, Task, mcp__codex__codex, mcp__codex__codex-reply
argument-hint: "[review-aspects] (例: all, code, tests, errors)"
---

# PR総合レビュー

pr-review-toolkit のエージェントレビューと Codex MCP のレビューを並列実行し、結果を統合する。

## コンテキスト

- 現在のブランチ: !`git branch --show-current`
- git status: !`git status --short`
- 変更ファイル: !`git diff --name-only HEAD~1 2>/dev/null || git diff --name-only`

## 実行手順

### 1. 変更内容の確認

`git diff` で変更内容を把握する。PRが存在する場合は `gh pr view` でPR情報も取得する。

### 2. 並列レビュー実行

以下の2つのレビューを**同時に並列実行**する。必ず1つのメッセージで両方のツールを呼び出すこと。

#### レビュー A: pr-review-toolkit エージェント群

Agent ツールで各専門エージェントを起動する。
$ARGUMENTS があればそれをレビュー対象として渡す。なければ全レビューを実行する。

必ず起動するエージェント:
- `pr-review-toolkit:code-reviewer` — コード品質、バグ、プロジェクトガイドライン準拠

変更内容に応じて追加起動:
- テストファイルが変更されている → `pr-review-toolkit:pr-test-analyzer`
- エラーハンドリングが変更されている → `pr-review-toolkit:silent-failure-hunter`
- 型定義が追加/変更されている → `pr-review-toolkit:type-design-analyzer`
- コメント/ドキュメントが追加されている → `pr-review-toolkit:comment-analyzer`

各エージェントは `run_in_background: true` で並列起動する。

#### レビュー B: Codex MCP レビュー

`mcp__codex__codex` を使用し、`sandbox: "read-only"` でレビューを実行する。
変更差分（`git diff`）を含めて、バグ・セキュリティ・設計上の問題・改善点を分析させる。

### 3. 意見の相違・追加確認の解消

両方のレビュー結果を比較し、以下のケースがあれば `mcp__codex__codex-reply` で Codex と追加のやりとりを行い、結論を出す:

- **意見の相違**: 一方が問題と指摘し、もう一方が問題視していない場合
- **重要度の判断が分かれる**: Critical vs Important など重要度の認識が異なる場合
- **追加の確認が必要**: 指摘内容の妥当性や影響範囲が不明確な場合

やりとりの結果、最終的な判断を下して統合結果に反映する。

### 4. 結果統合

両方のレビュー結果を以下のフォーマットで統合する。
同じ問題を指摘している場合は重複を排除し、情報をマージする。

```markdown
# PR総合レビュー結果

## Critical Issues（修正必須）
- [検出元: agent名/Codex] 問題の説明 [file:line]

## Important Issues（修正推奨）
- [検出元: agent名/Codex] 問題の説明 [file:line]

## Suggestions（検討事項）
- [検出元: agent名/Codex] 提案内容 [file:line]

## Positive Observations（良い点）
- 評価できるポイント

---

### レビューソース
- **pr-review-toolkit**: 実行されたエージェント一覧
- **Codex MCP**: レビュー完了
- **相違点の解消**: codex-reply でのやりとり回数（該当があれば）
```

### 5. 対応方針の提示

統合結果に基づき、推奨する対応順序を提示する:
1. Critical Issues を最優先で修正
2. Important Issues に対応
3. Suggestions は任意で検討

修正が必要な場合は、ユーザーに確認してから対応を開始する。
