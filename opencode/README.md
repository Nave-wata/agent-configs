# opencode サブエージェント

`agents/` は `.opencode/agents/` に展開される opencode 専用のサブエージェント定義（`mode: subagent`）。opencode がこのディレクトリ配下の `.md` を全てエージェント定義として読み込む可能性があるため、frontmatter を持たない本ファイルは `agents/` の外（`opencode/` 直下）に置いている。

## 出典

`agents/` 配下の6体は [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents)（MIT License, Copyright (c) 2025 AgentLand Contributors）の `engineering/` 部門から移植したもの。frontmatter を opencode 形式（`mode: subagent` 追加、`color` を hex 化、`emoji`/`vibe` を削除）に変換した以外、本文は無改変。

| ファイル | 元ファイル | 役割 |
|---|---|---|
| `agents/code-reviewer.md` | `engineering-code-reviewer.md` | コードレビュー（🔴blocker/🟡suggestion/💭nit分類） |
| `agents/codebase-onboarding-engineer.md` | `engineering-codebase-onboarding-engineer.md` | 未知コードベースの構造・実行パス解説 |
| `agents/software-architect.md` | `engineering-software-architect.md` | アーキテクチャ設計判断・ADR作成 |
| `agents/minimal-change-engineer.md` | `engineering-minimal-change-engineer.md` | 依頼範囲だけを最小差分で実装 |
| `agents/git-workflow-master.md` | `engineering-git-workflow-master.md` | ブランチ戦略・rebase/worktree等の高度なGit操作 |
| `agents/sre.md` | `engineering-sre.md` | SLO/エラーバジェット・オブザーバビリティ・信頼性運用 |

ライセンス全文: https://github.com/msitarzewski/agency-agents/blob/main/LICENSE

## 使い方

opencode 上で `@code-reviewer` のように `@` プレフィックスで手動呼び出しできるほか、primary エージェントが各エージェントの `description` を見て自動的に委譲することもある。

## 指示ドキュメント

opencode 専用の共通方針は `instructions.md`（展開後 `.opencode/instructions.md`、codex の `instructions.md` と同じ位置づけ）に記載し、`opencode.json` の `instructions` から参照している。description 頼みの自動委譲が弱いケースへの対策として、サブエージェントごとの使い分け・委譲判断基準もここに明記している。
