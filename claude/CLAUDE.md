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

## Superpowers Document Output Location

The output location for brainstorming designs and writing-plans implementation plans varies by project. **Always confirm the destination with the user** — possible options include GitHub Issue comments (`gh issue comment`), local files, or chat-only presentation.

When posting to a GitHub Issue:
- Confirm the issue number with the user before posting (do not guess)
- No git commit needed
