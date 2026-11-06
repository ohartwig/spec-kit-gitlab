---
description: "Show GitLab issue status and update tasks.md"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# GitLab issue status

Shows an overview of the feature's GitLab issues and updates the checkboxes in `tasks.md` to match GitLab.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). `--no-update` means: only show the overview, don't change `tasks.md`.

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `tasks.md` and `.gitlab-mapping.yml`

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR` and `TASKS`. All paths are absolute.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
MAPPING_PATH="$FEATURE_DIR/.gitlab-mapping.yml"
```

### Step 3: Load the mapping

```bash
list_mapping_ids "$MAPPING_PATH" tasks
list_mapping_ids "$MAPPING_PATH" stories
parse_tasks "$TASKS"
```

If there is no mapping file, build a temporary mapping from the ISSUE column of `parse_tasks` (`<!-- gitlab:#123 -->` comments).

If neither exists, tell the user to run `__SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__` first and abort.

### Step 4: Query the issues

Fetch all spec-kit issues in one request:

```bash
glab_list_issues "$GITLAB_SPECKIT_LABEL" all \
  | jq -r '.[] | [.iid, .state, ((.assignees // []) | map("@" + .username) | join(" ")), .updated_at] | @tsv'
```

For mapped issues missing from that list, fall back to `glab_view_issue <iid>`.

### Step 5: Detect discrepancies

Compare the local checkbox (STATUS from `parse_tasks`) with the GitLab state. Collect tasks where they differ:
- `[x]` locally, but the issue is open
- `[ ]` locally, but the issue is closed

### Step 6: Update tasks.md

Unless `--no-update` was passed:

- If there are no discrepancies, change nothing.
- If the only discrepancies are issues closed in GitLab but open locally, update `tasks.md` with `set_task_checkbox "$TASKS" <ID> done`.
- If there are tasks marked `[x]` locally whose issue is still open, don't silently uncheck them (that would undo local work). Show them and ask the user which side wins:
  - **GitLab wins:** `set_task_checkbox "$TASKS" <ID> open`
  - **Local wins:** suggest `__SPECKIT_COMMAND_GITLAB_CLOSE-ISSUES__`

### Step 7: Show the overview

```
Feature: #232 - <title> (Open)
URL: https://gitlab.example.com/.../issues/232
================================================

GitLab issue status for feature: <feature-name>

| Task  | GitLab | Status    | Assignee  |
|-------|--------|-----------|-----------|
| T001  | #42    | ✅ Closed | @username |
| T002  | #43    | 🔄 Open   | @other    |
| T003  | #44    | 🔄 Open   | -         |

Summary:
  Open:      2
  Closed:    1
  Total:     3
  Progress:  33%

| Story | GitLab | Status  | Tasks done |
|-------|--------|---------|------------|
| US1   | #10    | 🔄 Open | 1/3        |

Tasks without an issue: T004, T005
Last updated: <current date/time>
```

Leave out the feature block if no feature issue is mapped, and the "without an issue" line if there are none.
