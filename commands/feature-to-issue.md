---
description: "Create the feature as a GitLab issue and link stories"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Create the feature as a GitLab issue

Creates a GitLab issue for the current feature and links existing story issues to it.

## Prerequisites

- `glab` CLI is installed and authenticated (`GITLAB_TOKEN` set)
- GitLab configuration exists (`.specify/extensions/gitlab/gitlab-config.yml`)
- Feature directory with `spec.md` is present

## User Input

$ARGUMENTS

## Steps

### Step 1: Determine the feature directory

Use `{SCRIPT:check-prerequisites.sh}` to determine the current feature directory. The feature directory contains `spec.md`.

If no feature directory is found, inform the user and abort.

### Step 2: Load configuration

Load the GitLab configuration from `.specify/extensions/gitlab/gitlab-config.yml`. Use the helper functions from `{SCRIPT:gitlab-helpers.sh}`.

The following values are needed:
- `GITLAB_URL` - URL of the GitLab server
- `GITLAB_PROJECT` - project path
- `GITLAB_FEATURE_TO_ISSUE` - whether the feature is created as an issue
- `GITLAB_FEATURE_LABEL` - label for feature issues
- `GITLAB_FEATURE_TO_MILESTONE` - whether the feature is mapped to a milestone

If `GITLAB_FEATURE_TO_ISSUE` is not `true`, inform the user and abort:
> Feature-to-issue is disabled in the configuration (`feature_to_issue: false`).

### Step 3: Check idempotency

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml` (if present). Check the `feature:` entry with `read_feature_mapping`.

If a feature issue is already mapped, show the existing mapping and abort:
> Feature issue already exists: #232 (https://...)
> Skipping creation.

### Step 4: Create the feature issue

1. **Determine the feature name**: directory name of the feature directory (e.g. `user-authentication`).

2. **Extract the description** from `spec.md`: read the content before `## User Stories` (overview/context of the feature). If `## User Stories` doesn't exist, use the entire content of `spec.md`.

3. **Assemble labels:**
   - Always: `spec-kit`, the configured `GITLAB_FEATURE_LABEL` (default: `feature`)

4. **Determine the milestone** (if `feature_to_milestone: true`):
   ```bash
   MILESTONE_TITLE="$(glab_ensure_milestone "$(get_feature_name "$FEATURE_DIR")")"
   ```

5. **Create the issue** via `glab_create_issue`:
   - Title: feature name (human-readable, e.g. `user-authentication`)
   - Description: extracted context from `spec.md`
   - Labels: `spec-kit,feature`
   - Milestone: if set, `MILESTONE_TITLE`

6. **Extract the issue URL and number** from the output.

### Step 5: Write the mapping

Write the feature mapping to `FEATURE_DIR/.gitlab-mapping.yml`:

```bash
write_feature_mapping "$MAPPING_PATH" "$ISSUE_NUMBER" "$ISSUE_URL"
```

This produces e.g.:
```yaml
feature: "#232 https://gitlab.example.com/group/project/-/issues/232"
stories:
  US1: "#10 https://..."
tasks: {}
```

### Step 6: Link existing stories

Read all entries from `stories:` in the mapping file. For each story entry:

1. Extract the story issue number
2. Link the story issue to the feature issue:
   ```bash
   glab_add_relation "$STORY_ISSUE_NUMBER" "$FEATURE_ISSUE_NUMBER"
   ```

If no stories are present, skip this step with a note:
> No existing story issues found to link.

### Step 7: Summary

Show an overview:
- Feature issue created: `#232 - user-authentication`
- URL: `https://gitlab.example.com/.../issues/232`
- Milestone: if set
- Linked stories: count and list
- Note: "Run `/speckit.gitlab.stories-to-issues` to create new stories — they will be linked automatically."
