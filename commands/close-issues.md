---
description: "Close completed tasks/stories in GitLab, reopen reopened ones"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Close completed issues in GitLab

Pushes the local completion status (checkboxes in `tasks.md`) to GitLab: completed tasks and stories are closed, reopened ones are reopened. This is the push direction; `__SPECKIT_COMMAND_GITLAB_SYNC__` pulls the GitLab status into `tasks.md`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). `--dry-run` means: show what would change, but don't change anything in GitLab.

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `tasks.md` and `.gitlab-mapping.yml` (`__SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__`)

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR` and `TASKS`. All paths are absolute.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
```

### Step 3: Load the mapping file and tasks.md

The mapping file is `$FEATURE_DIR/.gitlab-mapping.yml`. If it doesn't exist, tell the user to run `__SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__` first and abort.

```bash
MAPPING_PATH="$FEATURE_DIR/.gitlab-mapping.yml"
list_mapping_ids "$MAPPING_PATH" tasks     # T001<TAB>#42 https://...
list_mapping_ids "$MAPPING_PATH" stories   # US1<TAB>#10 https://...
parse_tasks "$TASKS"                       # ID, STATUS (open/done), STORY, ...
```

A task's issue number comes from the mapping or, if missing there, from the ISSUE column (`<!-- gitlab:#42 -->`).

### Step 4: Query the current GitLab status

Fetch the state of all mapped issues in one request instead of one call per issue:

```bash
glab_list_issues "$GITLAB_SPECKIT_LABEL" all | jq -r '.[] | "\(.iid)\t\(.state)"'
```

For mapped issues missing from that list (for example because the label was removed), fall back to `glab_issue_state <iid>`.

### Step 5: Reconcile tasks

For each mapped task:

1. **Done locally + `opened` in GitLab** → `glab_close_issue <iid>`
2. **Open locally + `closed` in GitLab** → `glab_reopen_issue <iid>`
3. **Status matches** → skip

A task that is in the mapping but no longer in `tasks.md` is reported as "orphaned" and left unchanged.

### Step 6: Reconcile stories

Stories have no checkboxes in `spec.md`. A story counts as done when **all** tasks with its `[USx]` marker are done.

For each mapped story:

1. All its tasks done + story issue `opened` → close it
2. Not all tasks done + story issue `closed` → reopen it
3. Story has no tasks → skip

### Step 7: Reconcile the feature issue

If a feature issue is mapped (`read_feature_mapping "$MAPPING_PATH"`):

1. All story issues closed (and all tasks done) + feature issue open → ask the user:
   > All stories are complete. Should feature issue #232 be closed?
2. Open stories or tasks + feature issue closed → ask the user:
   > Feature issue #232 is closed, but there are still open stories. Should it be reopened?

Never close or reopen the feature issue without the user's confirmation.

### Step 8: Summary

```
Issues closed/reopened for feature: <feature-name>
========================================================

Closed:
  T001 → #42
  T003 → #44
  US1  → #10 (all tasks complete)

Reopened:
  T002 → #43

Unchanged: 2   Orphaned: 0

Closed: 3   Reopened: 1
```

With `--dry-run`, show the same table under the heading "Would change" and change nothing.
