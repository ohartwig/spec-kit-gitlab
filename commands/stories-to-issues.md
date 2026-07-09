---
description: "Create user stories from spec.md as GitLab issues"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Create user stories as GitLab issues

Create a parent GitLab issue for each user story in `spec.md`.

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
- Labels: `spec-kit`, `user-story`
- `GITLAB_FEATURE_TO_MILESTONE` - whether the feature is mapped to a milestone

If `feature_to_milestone: true`, determine the feature name from the feature directory (directory name) and make sure a corresponding milestone exists in GitLab:

```bash
MILESTONE_TITLE="$(glab_ensure_milestone "$(get_feature_name "$FEATURE_DIR")")"
```

### Step 3: Read spec.md and extract user stories

Read the `spec.md` file in the feature directory. Extract all user stories. User stories are typically in this format:

```markdown
## User Stories

### US1: Story title [P1]
As a <role> I want <capability>, so that <benefit>.

**Acceptance criteria:**
- Criterion 1
- Criterion 2

### US2: Story title [P2]
...
```

Extract for each story:
- **Story ID**: e.g. `US1`
- **Title**: e.g. "Story title"
- **Priority**: e.g. `P1`
- **Description**: the user story in "As a... I want... so that..." format
- **Acceptance criteria**: list of criteria

### Step 4: Check idempotency

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml` (if present). Skip stories that already have a GitLab issue number there.

### Step 5: Create GitLab issues

For each story not yet created:

1. **Assemble labels:**
   - Always: `spec-kit`, `user-story`
   - If priority is set: `priority::1` (for P1), `priority::2` (for P2), etc.

2. **Format the issue description:**
   ```markdown
   **Story ID:** US1
   **Priority:** P1

   ## User Story
   As a <role> I want <capability>, so that <benefit>.

   ## Acceptance Criteria
   - [ ] Criterion 1
   - [ ] Criterion 2
   ```

3. **Create the issue** via `glab`:
   ```bash
   glab issue create \
     --repo "$GITLAB_PROJECT" \
     --title "US1: Story title" \
     --description "<formatted description>" \
     --label "spec-kit,user-story,priority::1" \
     --milestone "$MILESTONE_TITLE" \
     --yes
   ```

   Only set the `--milestone` parameter if `feature_to_milestone: true` and `MILESTONE_TITLE` is set. Use `glab_create_issue` with the 5th parameter for the milestone.

4. **Extract the issue URL and number** from the output.

5. **Link to the feature issue:**
   If `feature:` is set in `.gitlab-mapping.yml`, link the newly created story issue to the feature issue:
   ```bash
   FEATURE_MAPPING="$(read_feature_mapping "$MAPPING_PATH")"
   if [[ -n "$FEATURE_MAPPING" ]]; then
     FEATURE_ISSUE_NUMBER="$(extract_feature_issue_number "$FEATURE_MAPPING")"
     glab_add_relation "$STORY_ISSUE_NUMBER" "$FEATURE_ISSUE_NUMBER"
   fi
   ```

### Step 6: Update the mapping file

Write/update the mapping file `FEATURE_DIR/.gitlab-mapping.yml`:

```yaml
stories:
  US1: "#10 https://gitlab.example.com/group/project/-/issues/10"
  US2: "#11 https://gitlab.example.com/group/project/-/issues/11"
tasks: {}
```

### Step 7: Summary

Show an overview:
- Number of story issues created
- Number of stories skipped (already present)
- Links to the created issues
- Note: "Run `/speckit.gitlab.tasks-to-issues` to link tasks with these stories."
