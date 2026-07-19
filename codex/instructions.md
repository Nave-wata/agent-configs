# Codex Project Instructions

- Always communicate with the user in Japanese.
- Treat `AGENTS.md` (or `CLAUDE.md` as a fallback) as the source of truth for repository rules, branch workflow, language/framework constraints, formatting rules, PR rules, and completion checks.
- Do not run build, test, or database commands locally unless the user confirms the required runtime is available in the current shell. When the runtime is unavailable, provide copy-paste commands for the developer to run in the appropriate environment instead.
- Use `gh` for GitHub operations. If `gh` fails with the known TLS error, fall back to `curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)"`.
- Never push directly to protected branches such as `main`. Work on `feature/*` branches and open pull requests.
- Do not read, write, or stage `.env`, key, or credential files.
- Confirm ambiguous requirements before implementation when multiple behavior interpretations are plausible.
- Consult the `advisor` custom agent once as a read-only second opinion before committing to a consequential design or finalizing work that is broad, security-sensitive, performance-sensitive, or crosses authentication, authorization, SQL, multilingual, or external API boundaries, or when a difficult bug remains uncertain.
- Do not use the advisor for routine implementation, small fixes, formatting, or documentation-only changes. Give it a narrow question, use at most one advisor at a time, and independently verify its advice before acting on it.
- Claude slash-command style workflows are available as Codex repo skills under `.codex/skills`. Use `$commit`, `$create-pr`, and `$release` when those workflows are requested.
