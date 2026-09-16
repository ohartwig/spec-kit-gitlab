---
description: "Close completed tasks/stories in GitLab, reopen reopened ones"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Close completed issues in GitLab

Syncs the local completion status (checkboxes in `tasks.md`) to GitLab: completed tasks/stories are closed, reopened ones are reopened.

## Prerequisites

- `glab` CLI is installed and authenticated (`GITLAB_TOKEN` set)
- GitLab configuration exists (`.specify/extensions/gitlab/gitlab-config.yml`)
- Feature directory with `tasks.md` and `.gitlab-mapping.yml` is present

## User Input

$ARGUMENTS

## Steps

### Step 1: Determine the feature directory

Use `{SCRIPT:check-prerequisites.sh}` to determine the current feature directory.

If no feature directory is found, inform the user and abort.

### Step 2: Load configuration

Load the GitLab configuration from `.specify/extensions/gitlab/gitlab-config.yml`. Use the helper functions from `{SCRIPT:gitlab-helpers.sh}`.

### Step 3: Load the mapping file and tasks.md

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml`. If no mapping file exists:
- Inform the user that `/speckit.gitlab.tasks-to-issues` must be run first
- Abort

Read `tasks.md` in the feature directory and extract for each task:
- **Task ID**: e.g. `T001`
- **Status**: `[x]` = complete, `[ ]` = open

### Step 4: Query the current GitLab status

For each issue number in the mapping file (both the `tasks:` and `stories:` sections), fetch the current status:

```bash
glab_view_issue "$ISSUE_NUMBER"
```

Extract the `state` (`opened` or `closed`).

### Step 5: Reconcile tasks and close/reopen issues

For each task in the mapping file:

1. **Complete locally (`[x]`) + open in GitLab (`opened`)** → Close the issue:
   ```bash
   glab_close_issue "$ISSUE_NUMBER"
   ```

2. **Open locally (`[ ]`) + closed in GitLab (`closed`)** → Reopen the issue:
   ```bash
   glab_reopen_issue "$ISSUE_NUMBER"
   ```

3. **Status matches** → Skip

### Step 6: Reconcile stories

Stories have no checkboxes in `spec.md`. Instead, a story is considered complete when **all its tasks** are complete.

For each story in the mapping file:

1. Determine all tasks that belong to this story (tasks with a `[USx]` reference in `tasks.md`)
2. If **all** associated tasks have `[x]` and the story issue is open → close the issue
3. If **not all** tasks are complete and the story issue is closed → reopen the issue
4. If the story has no tasks → skip

### Step 7: Reconcile the feature issue (optional)

If a feature issue is present in the mapping file (a `feature:` entry):

1. Check whether **all** story issues are closed
2. If yes and the feature issue is open → ask the user:
   > All stories are complete. Should feature issue #232 be closed?
3. If not all stories are complete and the feature issue is closed → inform the user:
   > Feature issue #232 is closed, but there are still open stories. Should it be reopened?

### Step 8: Summary

Show an overview:

```
Issues closed/reopened for feature: <feature-name>
========================================================

Closed:
  T001 → #42 (closed)
  T003 → #44 (closed)
  US1  → #10 (closed, all tasks complete)

Reopened:
  T002 → #43 (reopened)

Unchanged:
  T004 → #45 (already closed)
  T005 → #46 (already open)

Summary:
  Closed: 3
  Reopened: 1
  Unchanged: 2
```
