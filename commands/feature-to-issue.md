---
description: "Create the feature as a GitLab issue and link stories"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Create the feature as a GitLab issue

Creates a GitLab issue for the current feature and links existing story issues to it.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty), for example a custom issue title.

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `spec.md` (`__SPECKIT_COMMAND_SPECIFY__`)

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR` and `FEATURE_SPEC`. All paths are absolute.

If `FEATURE_SPEC` doesn't exist, tell the user to run `__SPECKIT_COMMAND_SPECIFY__` first and abort.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
```

If `GITLAB_FEATURE_TO_ISSUE` is not `true`, tell the user and abort:
> Feature-to-issue is disabled in the configuration (`feature_to_issue: false`).

### Step 3: Check idempotency

```bash
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
read_feature_mapping "$MAPPING_PATH"
```

If a feature issue is already mapped, show it and stop creating; continue with Step 6 to link stories that aren't linked yet:
> Feature issue already exists: #232 (https://...)

### Step 4: Create the feature issue

1. **Title:** the feature name from the first heading of `spec.md` (`# Feature Specification: <name>`). Fall back to the directory name (`get_feature_name "$FEATURE_DIR"`, e.g. `001-user-auth`).

2. **Description:** from `spec.md`, the content before `## User Scenarios & Testing` (or the legacy `## User Stories`), plus a short list of the user stories (`parse_stories "$FEATURE_SPEC"`) and a reference line:
   ```markdown
   <!-- Created by spec-kit from specs/001-user-auth/spec.md -->
   ```
   If neither heading exists, use the whole `spec.md`. Keep the description under 1 MB.

3. **Labels:** `$GITLAB_SPECKIT_LABEL,$GITLAB_FEATURE_LABEL`

4. **Milestone** (if `GITLAB_FEATURE_TO_MILESTONE` is `true`):
   ```bash
   MILESTONE_TITLE="$(glab_ensure_milestone "$(get_feature_name "$FEATURE_DIR")")"
   ```

5. **Create the issue:**
   ```bash
   OUT="$(glab_create_issue "$TITLE" "$DESCRIPTION" "$LABELS" "$MILESTONE_TITLE")"
   ISSUE_URL="$(extract_issue_url "$OUT")"
   ISSUE_NUMBER="$(extract_issue_number "$OUT")"
   ```
   If no issue URL comes back, show the glab output and abort.

### Step 5: Write the mapping

```bash
write_feature_mapping "$MAPPING_PATH" "$ISSUE_NUMBER" "$ISSUE_URL"
```

Result:
```yaml
feature: "#232 https://gitlab.example.com/group/project/-/issues/232"
stories:
  US1: "#10 https://..."
tasks: {}
```

### Step 6: Link existing stories

```bash
FEATURE_IID="$(extract_feature_issue_number "$(read_feature_mapping "$MAPPING_PATH")")"
list_mapping_ids "$MAPPING_PATH" stories   # prints "US1<TAB>#10 https://..."
```

For each story, link it to the feature issue (existing links are ignored):

```bash
glab_add_relation "$(extract_mapping_issue_number "$VALUE")" "$FEATURE_IID"
```

If there are no stories yet:
> No existing story issues found to link.

### Step 7: Summary

Show:
- Feature issue: `#232 - <title>` and its URL
- Milestone, if set
- Linked stories: count and list
- Next step: `__SPECKIT_COMMAND_GITLAB_STORIES-TO-ISSUES__` creates story issues that are linked automatically.
