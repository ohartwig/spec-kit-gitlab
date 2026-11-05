---
description: "Import an existing GitLab issue as a feature"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Import a GitLab issue as a feature

Takes an existing GitLab issue and adopts it as a feature in spec-kit.

## User Input

```text
$ARGUMENTS
```

The argument is the **issue number** of the GitLab issue to import (e.g. `232`, `#232`, or the issue URL).

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the issue number

Extract the issue number from the argument: `232`, `#232`, or a URL ending in `/-/issues/232`. If the URL points to a different project than the configured one, warn the user and abort.

If no argument was passed, ask the user for the issue number.

### Step 2: Load configuration

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
require_tools && load_gitlab_config
```

### Step 3: Fetch the issue from GitLab

```bash
glab_view_issue "$ISSUE_NUMBER" | jq '{iid, title, description, state, labels, web_url}'
```

If the issue is not found, tell the user and abort.

### Step 4: Determine the feature directory

Run `{SCRIPT}` from the project root and parse `FEATURE_DIR` from the JSON output.

If there is no active feature, or its directory doesn't exist yet, don't create one by hand. Tell the user to start the feature with spec-kit and pass the issue as input, for example:

> `__SPECKIT_COMMAND_SPECIFY__ <issue title> (GitLab #232)`

Then run this command again; it links the new feature directory to the issue. (spec-kit's specify command creates the numbered feature directory and branch.)

### Step 5: Check idempotency

```bash
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
read_feature_mapping "$MAPPING_PATH"
```

If a different feature issue is already mapped, ask the user:
> The feature directory is already linked to issue #XYZ.
> Should the mapping be updated to #232?

### Step 6: Write the mapping

```bash
write_feature_mapping "$MAPPING_PATH" "$ISSUE_NUMBER" "$ISSUE_URL"
```

Add the labels `$GITLAB_SPECKIT_LABEL` and `$GITLAB_FEATURE_LABEL` to the issue if they're missing:

```bash
glab_cmd issue update "$ISSUE_NUMBER" --label "$GITLAB_SPECKIT_LABEL,$GITLAB_FEATURE_LABEL"
```

### Step 7: Optional — seed spec.md

If `spec.md` doesn't exist yet or is still the empty template, and the issue has a description:

1. Create `spec.md` from the issue:
   ```markdown
   # Feature Specification: <issue title>

   <!-- Imported from GitLab issue #232: <issue URL> -->

   **Input**: GitLab issue #232

   <issue description>
   ```

2. Tell the user:
   > `spec.md` was seeded with the issue description.
   > Refine it with `__SPECKIT_COMMAND_SPECIFY__` or `__SPECKIT_COMMAND_CLARIFY__`.

If `spec.md` already has content, don't change it.

### Step 8: Link existing stories

For each entry from `list_mapping_ids "$MAPPING_PATH" stories`, link the story issue to the feature issue:

```bash
glab_add_relation "$(extract_mapping_issue_number "$VALUE")" "$ISSUE_NUMBER"
```

### Step 9: Summary and next steps

Show:
- Imported issue: `#232 - <title>` (Open/Closed)
- Feature directory
- Mapping written: yes
- spec.md seed: created / skipped
- Linked stories: count

Next steps:
```
1. __SPECKIT_COMMAND_SPECIFY__ / __SPECKIT_COMMAND_CLARIFY__  → Create or refine the specification
2. __SPECKIT_COMMAND_GITLAB_STORIES-TO-ISSUES__               → Stories as GitLab issues
3. __SPECKIT_COMMAND_PLAN__, __SPECKIT_COMMAND_TASKS__        → Plan and generate tasks
4. __SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__                 → Tasks as GitLab issues
```
