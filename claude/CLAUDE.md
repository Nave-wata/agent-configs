## Important

- All communication with users must be conducted in Japanese.
- Confirm any uncertainties with the user. Do not proceed with ambiguous information.

## Superpowers Document Output Location

The output location for brainstorming designs and writing-plans implementation plans varies by project. **Always confirm the destination with the user** — possible options include GitHub Issue comments (`gh issue comment`), local files, or chat-only presentation.

When posting to a GitHub Issue:
- Confirm the issue number with the user before posting (do not guess)
- No git commit needed

## GitHub CLI (gh) Usage Policy

Use the `gh` command for GitHub operations. Do not use GitHub MCP (Docker) — it creates excessive containers.

### Permissions (Fine-grained PAT)

- Read: actions, commit statuses, metadata
- Read/Write: code, issues, pull requests

### TLS Error Fallback

If `gh` fails with a TLS error (`x509: OSStatus -26276`), fall back to `curl -sk` with the gh token. This is also required for endpoints `gh` does not expose directly (e.g., PR pending review comments via `/pulls/{n}/reviews/{id}/comments`).

```bash
curl -sk -H "Authorization: token $(gh auth token 2>/dev/null)" "https://api.github.com/..."
```
