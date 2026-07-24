---
name: commit
description: Creates a git commit that complies with the project's commit rules. Automatically used when asked to create a commit, e.g. 「コミットして」「commit」「変更を保存」「git commit」. Obtains the issue number from arguments or conversation context; if undetermined, asks the user.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git switch:*), AskUserQuestion
argument-hint: <issue number or issue URL (optional)>
---

# Create Commit

## Context

- Current branch: !`git branch --show-current`
- git status: !`git status`
- Diff: !`git diff HEAD`
- Repository: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || git remote get-url origin 2>/dev/null`
- Recent commits: !`git log --oneline -10`

## Execution Steps

### 1. Check the Branch

If the current branch is main, automatically create and switch to a working branch:

1. Confirm the issue number (do step 2 first; if undetermined, ask the user)
2. Check existing branch naming patterns with `git branch -a` and decide a branch name following the repository's conventions
3. Create and switch to a new branch with `git switch -c {branch-name}`
4. Report the branch creation to the user and continue

### 2. Confirm the Issue Number

Extract the issue number from $ARGUMENTS (extraction from a URL is also fine). If there is no argument or it cannot be interpreted as an issue number, ask the user for the issue number. Do not proceed by guessing.

### 3. Analyze the Changes

Check git status and diff, and determine the following:
- Which files to stage (exclude .env and credential files)
- The appropriate change type
- The content of the commit message

### 4. Create the Commit

Create the commit in the following format (the actual commit summary/body text must be written in Japanese):

```
#<issue-number> [<change-type>]: <commit summary>

<background of the change>
<content of the change>
```

#### Change Types

| Type | Purpose |
|--------|------|
| feat | New feature |
| update | Changes or enhancements to an existing feature |
| fix | Bug fix |
| refactor | Refactoring only, no behavior change |
| test | Adding/modifying test code only |
| chore | Adding libraries, configuring GitHub Actions, etc. |

#### Rules

- **The summary line (line 1) must state "how the code changed."** Messages that don't convey what changed — like "review response," "addressed feedback," or "fix" — are prohibited. Even for review-driven fixes, phrase it as the actual change, e.g. `[fix]: null 参照でクラッシュする問題を修正` ("fixed a crash caused by a null reference") or `[refactor]: 重複バリデーションを共通関数に集約` ("consolidated duplicate validation into a shared function") — write these in Japanese, since commit messages are written in Japanese
  - If you want to **preserve the background**, e.g. "because it was flagged in review," **write it in the body's "background of the change" line or in an Issue knowledge comment** (not in the summary line)
- The detailed description (background of the change / content of the change) can be omitted for simple changes
- Pass the commit message using a HEREDOC:
  ```bash
  git commit -m "$(cat <<'EOF'
  #123 [feat]: メッセージ
  EOF
  )"
  ```
- Stage files by specifying individual filenames, not `git add -A`
- Write information you'll want to reference later — such as the reasoning behind design decisions or the process of root-cause investigation — in the body's "background of the change" section

### 5. Report the Result

After the commit completes, check the result with `git status` and report it.
