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

### Nested Subagents

Subagent nesting is enabled (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=3` in settings). It extends the Subagent-First workflow one level down: a coordinator subagent can itself dispatch workers, keeping both the main context and the coordinator's context clean.

- Good fit: hierarchical fan-out of independent subtasks — a coordinator dispatching parallel specialist workers (e.g., multi-perspective review), per-directory/per-component analysis in a large repo, investigation that fans out as it digs deeper.
- Structure for parallel decomposition, not pipelines: each layer has an isolated context, so order-dependent steps belong within one agent rather than across layers.
- Token cost scales with the total number of agents spawned, so match model to layer: `sonnet` for leaf workers, `opus`/`fable` for coordinators and hard verification.
- Communication is child-to-parent reporting only; design the tree so results roll up, and have siblings coordinate through their parent.

## Codex Plugin Usage

Codex (via the codex plugin) is an advisor providing an independent, cross-vendor second opinion — not a parallel implementation workforce. Routine implementation and exploration stay with Claude subagents.

- Second opinion / advisor: use `codex:rescue` when stuck after repeated failed attempts, when weighing design alternatives, or when an independent diagnosis adds value. Prefer read-only mode (diagnosis / investigation) — delegate write access only when explicitly intended.
- Reviews: **always include a Codex review pass** whenever reviewing code (before commit, PR creation, or on request). Use `/codex:review` for ordinary code review; use `/codex:adversarial-review` with a focus prompt when design decisions or trade-offs need challenging.
- Advisory checkpoints (recommended, not required): for non-trivial work, consult Codex once the approach/plan is settled — before implementation starts — via a read-only `codex:rescue`, asking it to challenge assumptions, risks, and simpler alternatives. Reuse the same thread (`--resume`) at later checkpoints (including the completion review) so the advisor retains context. Skip for trivial changes.
- Codex advisory is distinct from Claude subagent delegation: subagents execute work within the current plan with full conversation context; Codex evaluates the plan itself from outside, without that context. Do not route ordinary subagent work to Codex, and treat its feedback as a second opinion to weigh — not as instructions to apply verbatim.
- Prefer `--background` for large diffs or tasks; continue working and collect results with `/codex:status` / `/codex:result`.
- Never enable the stop-review-gate (`/codex:setup --enable-review-gate`) — it can create costly Claude/Codex auto-review loops.
