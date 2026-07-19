# opencode Project Instructions

- Always communicate with the user in Japanese.
- Confirm any uncertainties with the user. Do not proceed with ambiguous information.
- Treat the project's `AGENTS.md` / `CLAUDE.md` as the source of truth for repository rules,
  workflow, and completion checks.
- Claude-compatible skills are available from `.claude/skills/` (`commit`, `create-pr`,
  `release`). Use them when those workflows are requested.

## Subagent-First Workflow

The main session's job is orchestration: task breakdown, design decisions, and reviewing
results. The goal is to keep the main context limited to information needed for decisions —
delegate work whose intermediate output is large.

Delegate to subagents:

- Codebase exploration and investigation spanning multiple files → `@codebase-onboarding-engineer`
- Architecture decisions, design trade-offs, ADRs → `@software-architect`
- Implementation and debugging (trial-and-error generates noise) → `@minimal-change-engineer`
- Reviewing diffs before commit or PR creation → `@code-reviewer`
- Advanced git operations (rebase, worktree, history rewrite) → `@git-workflow-master`
- Reliability, observability, and operations concerns → `@sre`

Do directly (delegation overhead exceeds savings):

- Single gh/git commands, issue CRUD
- Reading short outputs needed verbatim for decisions (e.g., review comments)
- Any operation that completes in 1-2 tool calls with short output
