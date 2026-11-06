---
description: "Create user stories from spec.md as GitLab issues"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Create user stories as GitLab issues

Create a GitLab issue for each user story in `spec.md`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It may limit the run to specific stories (e.g. `US1 US3`).

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `spec.md`

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR` and `FEATURE_SPEC`. All paths are absolute.

If the script fails or `FEATURE_SPEC` doesn't exist, tell the user to run `__SPECKIT_COMMAND_SPECIFY__` first and abort.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
```

If this fails, show the error and point the user to `__SPECKIT_COMMAND_GITLAB_INIT__`.

If `GITLAB_FEATURE_TO_MILESTONE` is `true`, make sure the feature milestone exists:

```bash
MILESTONE_TITLE="$(glab_ensure_milestone "$(get_feature_name "$FEATURE_DIR")")"
```

### Step 3: Extract the user stories from spec.md

```bash
parse_stories "$FEATURE_SPEC"
```

This prints one line per story: `ID<TAB>PRIORITY<TAB>TITLE`. It understands the spec-kit template heading and the legacy format:

```markdown
### User Story 1 - Log in with SSO (Priority: P1)
### US1: Log in with SSO [P1]
```

Both become story ID `US1`. For each story, also read its section from `spec.md` (up to the next `###` heading or `---`):
- **Description**: the plain-language user journey
- **Why this priority** (if present)
- **Independent Test** (if present)
- **Acceptance Scenarios**: the numbered Given/When/Then list

If no stories are found, tell the user and abort.

### Step 4: Check idempotency

```bash
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
read_mapping "$MAPPING_PATH" stories US1   # prints "#10 https://..." if already created
```

Skip stories that already have an entry.

### Step 5: Create the GitLab issues

If a feature issue is mapped, look it up once so new stories are linked to it:

```bash
FEATURE_IID="$(extract_feature_issue_number "$(read_feature_mapping "$MAPPING_PATH")")"
```

For each story not yet created:

1. **Labels:** `$GITLAB_SPECKIT_LABEL,$GITLAB_STORY_LABEL`, plus `priority_to_label P1` (→ `priority::1`) if `GITLAB_PRIORITY_TO_LABEL` is `true` and the story has a priority.

2. **Description** (Markdown):
   ```markdown
   **Story ID:** US1
   **Priority:** P1
   **Feature:** <feature name>

   ## User Story
   <description>

   **Why this priority:** <text>

   **Independent Test:** <text>

   ## Acceptance Criteria
   - [ ] **Given** ..., **When** ..., **Then** ...
   ```
   Leave out sections that are empty.

3. **Create the issue** (the 5th argument links it to the feature issue, if any):
   ```bash
   OUT="$(glab_create_issue "US1: Log in with SSO" "$DESCRIPTION" "$LABELS" "$MILESTONE_TITLE" "$FEATURE_IID")"
   ISSUE_URL="$(extract_issue_url "$OUT")"
   ISSUE_NUMBER="$(extract_issue_number "$OUT")"
   ```
   Pass an empty milestone if `GITLAB_FEATURE_TO_MILESTONE` isn't `true`. If no issue URL comes back, report the glab output as an error for this story and continue with the next one.

4. **Write the mapping right away** (so a later failure doesn't cause duplicates):
   ```bash
   write_mapping "$MAPPING_PATH" stories US1 "$ISSUE_NUMBER" "$ISSUE_URL"
   ```

### Step 6: Summary

Show:
- Number of story issues created, with links
- Number of stories skipped (already present)
- Errors, if any
- Next step: run `__SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__` after `__SPECKIT_COMMAND_TASKS__` to create tasks linked to these stories.
