---
description: "Import and sync GitLab issues into spec-kit files"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Sync GitLab issues

Sync GitLab issues with the local spec-kit files (`tasks.md`).

## Prerequisites

- `glab` CLI is installed and authenticated (`GITLAB_TOKEN` set)
- GitLab configuration exists (`.specify/extensions/gitlab/gitlab-config.yml`)
- Feature directory with `tasks.md` is present

## User Input

$ARGUMENTS

## Steps

### Step 1: Determine the feature directory

Use `{SCRIPT:check-prerequisites.sh}` to determine the current feature directory.

If no feature directory is found, inform the user and abort.

### Step 2: Load configuration

Load the GitLab configuration from `.specify/extensions/gitlab/gitlab-config.yml`. Use the helper functions from `{SCRIPT:gitlab-helpers.sh}`.

### Step 3: Fetch the feature issue and issues from GitLab

If a feature issue is present in the mapping file (a `feature:` entry), fetch its current status:

```bash
FEATURE_MAPPING="$(read_feature_mapping "$MAPPING_PATH")"
if [[ -n "$FEATURE_MAPPING" ]]; then
  FEATURE_ISSUE_NUMBER="$(extract_feature_issue_number "$FEATURE_MAPPING")"
  FEATURE_STATUS="$(glab_view_issue "$FEATURE_ISSUE_NUMBER" | jq -r '.state')"
fi
```

Load all issues with the `spec-kit` label from the configured GitLab project:

```bash
# All issues with the spec-kit label (open and closed)
glab issue list --repo "$GITLAB_PROJECT" --label "spec-kit" --state all --output json
```

Parse the JSON output and extract for each issue:
- **Issue number**: e.g. `#42`
- **Title**: e.g. "T001: Task description"
- **Status**: `opened` or `closed`
- **Labels**: all labels of the issue
- **URL**: web URL of the issue

### Step 4: Load the mapping file

Read the existing mapping file `FEATURE_DIR/.gitlab-mapping.yml` (if present).

### Step 5: Update tasks.md

For each issue referenced in the mapping file or in `tasks.md` (via a `<!-- gitlab:#123 -->` comment):

1. **Closed issues**: set the checkbox to `[x]`
   ```
   - [x] T001 [P1] [US1] Task description <!-- gitlab:#42 -->
   ```

2. **Open issues**: set the checkbox to `[ ]`
   ```
   - [ ] T002 [P2] [US1] Other task description <!-- gitlab:#43 -->
   ```

### Step 6: Import new issues (optional)

If the user passed `--import` as an argument or confirms it:

For each GitLab issue with the `spec-kit` label that is NOT yet in `tasks.md`:

1. Determine the task ID from the issue title (e.g. "T001" from "T001: Description")
2. If there's no task ID in the title: generate the next free task ID
3. Determine the priority from labels (e.g. `priority::1` → `P1`)
4. Determine the story reference from labels (e.g. `story::US1` → `US1`)
5. Append the task at the end of `tasks.md`:
   ```
   - [ ] T099 [P2] [US3] Imported task description <!-- gitlab:#99 -->
   ```

### Step 7: Update the mapping file

Update the mapping file with all new assignments.

### Step 8: Summary

If a feature issue is present, show its status first:
```
Feature: #232 - user-authentication (Open)
```

Show an overview:
- Feature issue status (if present)
- Number of tasks updated (status changed)
- Number of tasks newly imported (if --import)
- Number of tasks unchanged
- Any conflicts or warnings
