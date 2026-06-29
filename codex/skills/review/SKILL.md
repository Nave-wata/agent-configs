---
name: review
description: Review code changes for correctness, security, and design issues, ordered by severity with file/line references. Use when the user asks for review, code review, PR review, change check, or review-fix guidance. Read-only and side-effect free.
---

# Review

## Repository (dynamic)

Do not hardcode the repository. When a GitHub API call is needed, resolve `{OWNER}/{REPO}` at runtime and read it as `$REPO`:

```sh
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
[ -z "$REPO" ] && REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
```

GitHub API URLs take the form `https://api.github.com/repos/${REPO}/...` (TLS fallback: `curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)"`).

## Scope

Review as a code reviewer. Findings lead the response, ordered by severity, with file and line references when possible. Focus on bugs, behavior regressions, missing checks, and missing verification. Codex performs the review itself; do not delegate to subagents or external review services.

## Process

1. Inspect `git status --short`, the current branch, and the relevant diff. Default to `{base}...HEAD` on working branches (base = the project's default branch). If a PR exists, also read its metadata via `gh pr view` or the GitHub API.
2. If the review target is ambiguous, ask the user before reviewing.
3. Classify findings:
   - Critical Issues: must fix before PR/merge.
   - Important Issues: should fix unless intentionally accepted.
   - Suggestions: optional improvements.
4. Keep summaries brief and secondary. If no issues are found, say so and mention residual verification gaps.

## Checks

General review aspects (apply those relevant to the change):

- Correctness: logic bugs, edge cases, off-by-one, null/empty handling, regressions in existing behavior.
- Authentication and authorization: access control, caller-specific behavior, privilege boundaries.
- SQL and data access: query conditions, pagination, scope, injection risk, migration/compatibility impact.
- Input validation and output encoding.
- External API and side effects: idempotency, error handling, retries, network/storage/3rd-party calls.
- Secret leakage: credentials, tokens, keys, dangerous commands, unintended production/data mutations.
- Compatibility: language/framework/runtime version constraints and dependency changes.
- Tests and verification: coverage of new logic, and whether the project's formatting/lint/test commands were run. If they were not (or cannot be run here), call out the gap and suggest the user run them.

## Fix Loop

When the user asks to apply review feedback, fix only Critical or Important items unless they approve Suggestions. After each fix, self-review the diff and commit with the `commit` skill when requested.
