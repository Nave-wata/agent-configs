# AGENTS.md

## Project Overview

agent-configs is a configuration-distribution repository that consolidates settings and skills for multiple AI coding agents (Claude Code / Codex / opencode) into a single repo, and deploys/updates them to each project via the `agent-setup` script.

## Notes When Working

### The Dual Structure of Distribution Source and Verification Instance

- The top-level `claude/` `codex/` `opencode/` are the **source of truth (distribution source)**. Always make edits here
- `.claude/` `.codex/` `.opencode/` are the **verification instance** produced by running `agent-setup` on this repository itself (not tracked by git)
- After changing the distribution source, rerun `bin/agent-setup` on this repository itself to apply and verify the changes

### Deployment Uses Copying

Deployment copies files rather than creating symlinks (to prevent broken links when running under sbx). Editing the central source does not automatically propagate to each project; `agent-setup` must be rerun in each project.

### Maintaining Portability

Do not hardcode repository names or machine-specific paths in skills/settings. Retrieve repository information dynamically at runtime from `gh` / `git remote`.

## Tech Stack

- Deployment script: Bash (`bin/agent-setup`)
- Codex hooks: Python 3 (standard library only)
- Distributed artifacts: Markdown (CLAUDE.md, skills) / JSON / TOML
- Runtime environment: local only (no production environment, DB, or CI). Agent execution **assumes sbx (Docker Sandboxes)**

## Directory Structure

```
agent-configs/
├── bin/agent-setup   # deployment script (this single file handles distribution and updates)
├── claude/           # → deployed to <project>/.claude/ (CLAUDE.md, skills, statusline)
├── codex/            # → deployed to <project>/.codex/ (config, hooks, rules, skills)
└── opencode/         # → deployed to <project>/.opencode/ (settings, agents, skills)
```

Each top-level directory `X/` corresponds to `.X/` in the destination project.

## Main Commands

```sh
# Deploy to this repository itself and verify
bin/agent-setup -y .

# Deploy only specific tools
bin/agent-setup --claude -y .

# Bash syntax check
bash -n bin/agent-setup
```

Tests / lint / CI are all **not yet set up** (don't unilaterally introduce shellcheck etc. — discuss it in review).

## Branch and Commit Practices

- **Work and commit directly on the main branch by default.** No working branch or PR is needed. Work on main unless instructed otherwise.
- **Do not attach an Issue number** to commits. Format: `[<change-type>]: <one-line summary>` + background/details, with the actual content written in Japanese (see the `/commit` skill for details)

## Prohibited

- Writing or committing credentials (API keys, tokens, etc.) to files. This project **assumes use within sbx**, and credentials are injected via `sbx secret`, so do not write them into config files (note that `settings.local.json` **is tracked by git** in this repository)
- Finishing work having edited only `.claude/` `.codex/` `.opencode/` (the verification instances) (direct edits for verification purposes are fine; the final change must always be reflected in the distribution source `claude/` `codex/` `opencode/`)
- Hardcoding project-specific or machine-specific paths into distributed artifacts

## Behavior When Something Is Unclear

- If the spec or policy is unclear, **confirm with the user** before proceeding with implementation
- If multiple interpretations are possible, present the candidates and ask for a decision

## Pre-Completion Checklist

Since tests are not set up, this is manual-verification based:

- [ ] When changing the script: `bash -n bin/agent-setup` passes, and `bin/agent-setup -y .` produces the expected deployment results/manifest
- [ ] When changing distributed artifacts: confirm no contradiction with README.md's description (structure, skill-porting scope table)
- [ ] Read through the diff and confirm there are no unexpected changes
