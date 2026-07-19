## Important

- All communication with users must be conducted in Japanese.
- Confirm any uncertainties with the user. Do not proceed with ambiguous information.

## Subagent-First Workflow

The main session's job is orchestration: task breakdown, design decisions, and reviewing results. The goal is to keep the main context limited to information needed for decisions — delegate work whose intermediate output is large.

Delegate to subagents (Agent tool):

- Codebase exploration and investigation spanning multiple files
- Implementation and debugging (trial-and-error generates noise)
- Summarizing large diffs, logs, or long command outputs

Do directly (delegation overhead exceeds savings):

- Single gh/git commands, issue CRUD
- Reading short outputs needed verbatim for decisions (e.g., review comments)
- Any operation that completes in 1-2 tool calls with short output

Model selection for subagents:

- Default: `opus` (also when unsure)
- Simple tasks (search, mechanical edits, small fixes): `sonnet`
- Heavy tasks (complex design, hard debugging, large refactors): `fable`

## Codex Plugin Usage

Codex (via the codex plugin) is an advisor providing an independent, cross-vendor second opinion — not a parallel implementation workforce. Routine implementation and exploration stay with Claude subagents.

- Second opinion / advisor: use `codex:rescue` when stuck after repeated failed attempts, when weighing design alternatives, or when an independent diagnosis adds value. Prefer read-only mode (diagnosis / investigation) — delegate write access only when explicitly intended.
- Reviews: **always include a Codex review pass** whenever reviewing code (before commit, PR creation, or on request). Use `/codex:review` for ordinary code review; use `/codex:adversarial-review` with a focus prompt when design decisions or trade-offs need challenging.
- Advisory checkpoints (recommended, not required): for non-trivial work, consult Codex once the approach/plan is settled — before implementation starts — via a read-only `codex:rescue`, asking it to challenge assumptions, risks, and simpler alternatives. Reuse the same thread (`--resume`) at later checkpoints (including the completion review) so the advisor retains context. Skip for trivial changes.
- Codex advisory is distinct from Claude subagent delegation: subagents execute work within the current plan with full conversation context; Codex evaluates the plan itself from outside, without that context. Do not route ordinary subagent work to Codex, and treat its feedback as a second opinion to weigh — not as instructions to apply verbatim.
- Prefer `--background` for large diffs or tasks; continue working and collect results with `/codex:status` / `/codex:result`.
- Never enable the stop-review-gate (`/codex:setup --enable-review-gate`) — it can create costly Claude/Codex auto-review loops.

## Superpowers Document Output Location

The output location for brainstorming designs and writing-plans implementation plans varies by project. **Always confirm the destination with the user** — possible options include GitHub Issue comments (`gh issue comment`), local files, or chat-only presentation.

When posting to a GitHub Issue:
- Confirm the issue number with the user before posting (do not guess)
- No git commit needed
