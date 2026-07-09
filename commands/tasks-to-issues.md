---
description: "Create tasks from tasks.md as GitLab issues (Type: Task)"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Create tasks as GitLab issues

Create a GitLab issue of type "Task" for each task in `tasks.md`.

## Prerequisites

- `glab` CLI is installed and authenticated (`GITLAB_TOKEN` set)
- GitLab configuration exists (`.specify/extensions/gitlab/gitlab-config.yml`)
- Feature directory with `tasks.md` is present

## User Input

$ARGUMENTS

## Steps

### Step 1: Determine the feature directory

Use `{SCRIPT:check-prerequisites.sh}` to determine the current feature directory. The feature directory contains `tasks.md`.

If no feature directory is found, inform the user and abort.

### Step 2: Load configuration

Load the GitLab configuration from `.specify/extensions/gitlab/gitlab-config.yml`. Use the helper functions from `{SCRIPT:gitlab-helpers.sh}`.

The following values are needed:
- `GITLAB_URL` - URL of the GitLab server
- `GITLAB_PROJECT` - project path (e.g. "group/project")
- Labels: `spec-kit`, `task`, and priority labels if applicable
- `GITLAB_FEATURE_TO_MILESTONE` - whether the feature is mapped to a milestone

If `GITLAB_URL` or `GITLAB_PROJECT` are not set, also check the environment variables.

If `feature_to_milestone: true`, determine the feature name and make sure a milestone exists:

```bash
MILESTONE_TITLE="$(glab_ensure_milestone "$(get_feature_name "$FEATURE_DIR")")"
```

### Step 3: Read and parse tasks.md

Read the `tasks.md` file in the feature directory. Parse each task in the format:

```
- [ ] T001 [P1] [US1] Task description
- [x] T002 [P2] [US1] Already completed task
```

Extract for each task:
- **Task ID**: e.g. `T001`
- **Priority**: e.g. `P1` (from `[P1]`)
- **Story reference**: e.g. `US1` (from `[US1]`)
- **Description**: the rest of the line
- **Status**: `[ ]` = open, `[x]` = complete

### Step 4: Check idempotency

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml` (if present). Skip tasks that already have a GitLab issue number there.

Also check whether `tasks.md` already has GitLab URLs as comments (format: `<!-- gitlab:#123 -->`). Skip these tasks as well.

### Step 5: Create GitLab issues

For each task not yet created:

1. **Assemble labels:**
   - Always: `spec-kit`, `task`
   - If priority is set: `priority::1` (for P1), `priority::2` (for P2), etc.
   - Story label: `story::US1` (if a story reference is present)

2. **Create the issue** via `glab`:
   ```bash
   glab issue create \
     --repo "$GITLAB_PROJECT" \
     --title "T001: Task description" \
     --description "**Task ID:** T001\n**Priority:** P1\n**Story:** US1\n\nTask description" \
     --label "spec-kit,task,priority::1,story::US1" \
     --type "task" \
     --milestone "$MILESTONE_TITLE" \
     --yes
   ```

   Only set the `--milestone` parameter if `feature_to_milestone: true` and `MILESTONE_TITLE` is set. Use `glab_create_issue` with the 5th parameter for the milestone.

3. **Extract the issue URL and number** from the output.

4. **Link to the story issue** (if `link_tasks_to_stories: true` and a story issue exists):
   ```bash
   glab issue relation add <task-issue-nr> --related <story-issue-nr> --repo "$GITLAB_PROJECT"
   ```

### Step 6: Update the mapping and tasks.md

1. **Update the mapping file** (`FEATURE_DIR/.gitlab-mapping.yml`):
   ```yaml
   tasks:
     T001: "#42 https://gitlab.example.com/group/project/-/issues/42"
     T002: "#43 https://gitlab.example.com/group/project/-/issues/43"
   ```

2. **Add GitLab references to tasks.md** (as an HTML comment at the end of the line):
   ```
   - [ ] T001 [P1] [US1] Task description <!-- gitlab:#42 -->
   ```

### Step 7: Summary

Show an overview:
- Number of issues created
- Number of issues skipped (already present)
- Links to the created issues
- Any errors
