---
description: "Import an existing GitLab issue as a feature"
scripts:
  check-prerequisites.sh: "../../scripts/check-prerequisites.sh"
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Import a GitLab issue as a feature

Takes an existing GitLab issue and adopts it as a feature in spec-kit.

## Prerequisites

- `glab` CLI is installed and authenticated (`GITLAB_TOKEN` set)
- GitLab configuration exists (`.specify/extensions/gitlab/gitlab-config.yml`)

## User Input

$ARGUMENTS

The argument is the **issue number** of the GitLab issue to import (e.g. `232` or `#232`).

## Steps

### Step 1: Determine the issue number

Extract the issue number from the argument. Accept formats such as `232`, `#232`, or a full GitLab URL.

If no argument was passed, ask the user for the issue number.

### Step 2: Load configuration

Load the GitLab configuration from `.specify/extensions/gitlab/gitlab-config.yml`. Use the helper functions from `{SCRIPT:gitlab-helpers.sh}`.

### Step 3: Fetch the issue from GitLab

Fetch the issue details:

```bash
glab_view_issue "$ISSUE_NUMBER"
```

Extract:
- **Title**: e.g. `user-authentication`
- **Description**: issue body
- **Status**: `opened` or `closed`
- **Labels**: current labels
- **URL**: web URL of the issue

If the issue is not found, inform the user and abort.

### Step 4: Determine the feature directory

Use `{SCRIPT:check-prerequisites.sh}` to determine the current feature directory.

If no feature directory is found:
- Derive the directory name from the issue title (lowercase, spaces replaced with hyphens)
- Inform the user of the proposed path
- Ask whether the directory should be created

### Step 5: Check idempotency

Read the mapping file `FEATURE_DIR/.gitlab-mapping.yml` (if present). Check the `feature:` entry.

If a different feature issue is already mapped, warn the user:
> The feature directory is already linked to issue #XYZ.
> Should the mapping be updated to #232?

### Step 6: Write the mapping

Initialize the mapping file (if needed) and write the feature mapping:

```bash
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
write_feature_mapping "$MAPPING_PATH" "$ISSUE_NUMBER" "$ISSUE_URL"
```

### Step 7: Optional — spec.md seed

If no `spec.md` exists yet in the feature directory and the issue has a description:

1. Create an initial `spec.md` using the issue description as a starting point:
   ```markdown
   # Feature Title

   <!-- Imported from GitLab issue #232 -->

   <Issue description>

   ## User Stories

   <!-- Create user stories with /speckit.spec -->
   ```

2. Inform the user:
   > `spec.md` was seeded with the issue description.
   > Refine the specification with `/speckit.spec`.

If `spec.md` already exists, skip this step.

### Step 8: Link existing stories

If story issues are present in the mapping file (the `stories:` section), link them to the feature issue:

```bash
glab_add_relation "$STORY_ISSUE_NUMBER" "$FEATURE_ISSUE_NUMBER"
```

### Step 9: Summary and next steps

Show an overview:
- Imported issue: `#232 - user-authentication`
- Status: `Open`
- Feature directory: `<path>`
- Mapping written: yes
- spec.md seed: created / skipped (already present)
- Linked stories: count

Next steps:
```
1. /speckit.spec                      → Create/refine the specification
2. /speckit.tasks                     → Generate tasks
3. /speckit.gitlab.stories-to-issues  → Stories as GitLab issues
4. /speckit.gitlab.tasks-to-issues    → Tasks as GitLab issues
```
