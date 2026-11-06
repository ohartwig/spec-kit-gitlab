---
description: "Import and sync GitLab issues into spec-kit files"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Sync GitLab issues

Pulls the GitLab issue status into the local `tasks.md` (GitLab → local). Optionally imports issues that don't exist locally yet. The opposite direction is `__SPECKIT_COMMAND_GITLAB_CLOSE-ISSUES__`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). Supported flags:
- `--import`: also add GitLab issues that aren't in `tasks.md` yet
- `--dry-run`: show what would change, don't write files

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `tasks.md`

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR` and `TASKS`. All paths are absolute.

If `TASKS` doesn't exist, tell the user to run `__SPECKIT_COMMAND_TASKS__` first and abort.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
```

### Step 3: Fetch the feature issue and the issues from GitLab

If a feature issue is mapped, fetch it:

```bash
FEATURE_IID="$(extract_feature_issue_number "$(read_feature_mapping "$MAPPING_PATH")")"
[[ -n "$FEATURE_IID" ]] && glab_view_issue "$FEATURE_IID" | jq '{iid, title, state, web_url}'
```

Load all issues with the spec-kit label (all pages, open and closed):

```bash
glab_list_issues "$GITLAB_SPECKIT_LABEL" all \
  | jq -r '.[] | [.iid, .state, (.labels | join(",")), .web_url, .title] | @tsv'
```

If `GITLAB_FEATURE_TO_MILESTONE` is `true`, only consider issues in this feature's milestone (`.milestone.title == <feature name>`), so issues of other features aren't imported.

### Step 4: Match issues to tasks

```bash
parse_tasks "$TASKS"
list_mapping_ids "$MAPPING_PATH" tasks
```

A task is matched to an issue by, in this order:
1. the mapping file entry
2. the `<!-- gitlab:#42 -->` comment on its line
3. the issue title: a task ID matching `\bT\d{3,}\b` (e.g. `T012: ...`)

### Step 5: Update tasks.md

For each matched task whose status differs:

```bash
set_task_checkbox "$TASKS" T012 done   # issue closed
set_task_checkbox "$TASKS" T013 open   # issue opened
```

Only touch lines whose status really changes. If a matched task had no mapping entry yet, add it (`write_mapping`) and the line comment (`annotate_task_issue`).

### Step 6: Import new issues (only with `--import`, or after the user confirms)

For each issue that isn't matched to a task and has the `$GITLAB_TASK_LABEL` label (story and feature issues are never imported as tasks):

1. **Task ID:** from the title (`T099: ...`); otherwise the next free ID (highest existing ID + 1, at least three digits)
2. **Story:** from a `story::US1` label
3. **Description:** the title without the task ID prefix
4. Append the task to the end of `tasks.md` under a heading `## Imported from GitLab` (create it once):
   ```
   - [ ] T099 [US3] Imported task description <!-- gitlab:#99 -->
   ```
   Use `[x]` for closed issues. Don't add a `[P]` marker: whether it can run in parallel is unknown.
5. Write the mapping: `write_mapping "$MAPPING_PATH" tasks T099 99 "$URL"`

### Step 7: Summary

If a feature issue is mapped, show it first:
```
Feature: #232 - <title> (Open)
```

Then:
- Tasks updated (status changed), with the direction (open → done, done → open)
- Tasks newly imported (with `--import`)
- Tasks unchanged
- Warnings: mapped issues that no longer exist, tasks without an issue (suggest `__SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__`)
