---
description: "Update the status of GitLab issues in tasks.md and show an overview"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Sync GitLab issue status

Update the status of the tasks in `tasks.md` based on the current GitLab issue status and show an overview.

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

### Step 3: Load the mapping file

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml`. This contains the mapping of task IDs to GitLab issue numbers.

If no mapping file exists, check `tasks.md` for `<!-- gitlab:#123 -->` comments and build a temporary mapping from those.

If neither a mapping file nor comments are present:
- Inform the user that `/speckit.gitlab.tasks-to-issues` must be run first
- Abort

### Step 4: Query the status of each issue

For each issue number in the mapping file:

```bash
glab issue view <issue-number> --repo "$GITLAB_PROJECT" --output json
```

Extract:
- **Status**: `opened` or `closed`
- **Labels**: current labels
- **Assignee**: assigned person (if any)
- **Updated at**: last update date

### Step 5: Update tasks.md

For each task with an assigned GitLab issue:

1. **Closed issue** → set `[x]` in tasks.md
2. **Open issue** → set `[ ]` in tasks.md

Only make actual changes (avoid unnecessary writes).

### Step 6: Show the overview

If a feature issue is present in the mapping file (a `feature:` entry), fetch its status and show it first:

```bash
FEATURE_MAPPING="$(read_feature_mapping "$MAPPING_PATH")"
if [[ -n "$FEATURE_MAPPING" ]]; then
  FEATURE_ISSUE_NUMBER="$(extract_feature_issue_number "$FEATURE_MAPPING")"
  # Fetch issue details via glab_view_issue
fi
```

Show a formatted table:

```
Feature: #232 - user-authentication (Open)
URL: https://gitlab.example.com/.../issues/232
================================================

GitLab issue status for feature: <feature-name>
================================================

| Task  | GitLab  | Status      | Assignee    |
|-------|---------|-------------|-------------|
| T001  | #42     | ✅ Closed   | @username   |
| T002  | #43     | 🔄 Open    | @other      |
| T003  | #44     | 🔄 Open    | -           |

Summary:
  Open:      2
  Closed:    1
  Total:     3
  Progress:  33%

Stories:
| Story | GitLab  | Status      |
|-------|---------|-------------|
| US1   | #10     | 🔄 Open    |

Last updated: <current date/time>
```

### Step 7: Bidirectional warning

If there are discrepancies (e.g. a task marked `[x]` in tasks.md but the GitLab issue is still open):
- Show a warning with the affected tasks
- Ask the user whether the GitLab status or the local status should take precedence
