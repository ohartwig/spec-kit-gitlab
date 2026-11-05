---
description: "Create tasks from tasks.md as GitLab issues (Type: Task)"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --paths-only
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly
---

# Create tasks as GitLab issues

Create a GitLab issue (type "Task" by default) for each task in `tasks.md`.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It may limit the run to specific tasks (e.g. `T001-T010`) or one story (e.g. `US2`).

## Prerequisites

- `glab` CLI is installed and authenticated (`glab auth login` or `GITLAB_TOKEN`), `jq` is installed
- The GitLab configuration exists (`__SPECKIT_COMMAND_GITLAB_INIT__`)
- The feature directory contains `tasks.md` (`__SPECKIT_COMMAND_TASKS__`)

Run all commands from the project root. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.

## Steps

### Step 1: Determine the feature directory

Run `{SCRIPT}` from the project root and parse the JSON output for `FEATURE_DIR`, `FEATURE_SPEC` and `TASKS`. All paths are absolute.

If `TASKS` doesn't exist, tell the user to run `__SPECKIT_COMMAND_TASKS__` first and abort.

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

### Step 3: Parse tasks.md

```bash
parse_tasks "$TASKS"
```

This prints one line per task:

```
ID<TAB>STATUS<TAB>STORY<TAB>PRIORITY<TAB>PARALLEL<TAB>ISSUE<TAB>DESCRIPTION
```

It understands the spec-kit task format, where `[P]` marks a task that can run in parallel and `[US1]` the user story it belongs to:

```
- [ ] T001 Create project structure per implementation plan
- [ ] T012 [P] [US1] Create User model in src/models/user.py
- [X] T014 [US1] Implement UserService in src/services/user_service.py
```

- **STATUS** is `open` for `[ ]` and `done` for `[x]`/`[X]`.
- **PRIORITY** is only set by a legacy `[P1]`-style marker. Otherwise the task inherits the priority of its story: look it up with `parse_stories "$FEATURE_SPEC"` (if `spec.md` exists).
- **ISSUE** is set when the line already has a `<!-- gitlab:#42 -->` comment.

Also note the phase heading (`## Phase N: ...`) each task is under; it goes into the issue description.

### Step 4: Check idempotency

```bash
MAPPING_PATH="$(init_mapping_file "$FEATURE_DIR")"
read_mapping "$MAPPING_PATH" tasks T001
```

Skip tasks that have a mapping entry or an ISSUE value from Step 3.

### Step 5: Create the GitLab issues

For each task not yet created:

1. **Labels:** `$GITLAB_SPECKIT_LABEL,$GITLAB_TASK_LABEL`, plus
   - `priority::N` if `GITLAB_PRIORITY_TO_LABEL` is `true` and a priority is known (`priority_to_label P1`)
   - `story::US1` if the task belongs to a story
   - `parallel` is **not** a label; mention it in the description instead

2. **Description** (Markdown):
   ```markdown
   **Task ID:** T012
   **Story:** US1 (#10)
   **Priority:** P1
   **Phase:** Phase 3: User Story 1 - Log in with SSO
   **Parallelizable:** yes

   Create User model in src/models/user.py
   ```
   Leave out lines that don't apply.

3. **Linked story:** if `GITLAB_LINK_TASKS` is `true` and the story has an issue (`read_mapping "$MAPPING_PATH" stories US1`), pass its number so the issues are linked on creation.

4. **Create the issue:**
   ```bash
   OUT="$(glab_create_issue "T012: Create User model in src/models/user.py" "$DESCRIPTION" "$LABELS" "$MILESTONE_TITLE" "$STORY_IID")"
   ISSUE_URL="$(extract_issue_url "$OUT")"
   ISSUE_NUMBER="$(extract_issue_number "$OUT")"
   ```
   Use the title format `T012: <description>` (task ID once, then the description without markers). Pass an empty milestone if `GITLAB_FEATURE_TO_MILESTONE` isn't `true`. If no issue URL comes back, report the glab output as an error for this task and continue with the next one.

5. **Set the issue type** (`task` by default, `issue` leaves it unchanged):
   ```bash
   glab_set_issue_type "$ISSUE_NUMBER" "$GITLAB_TASK_ISSUE_TYPE"
   ```
   If this prints a warning, the issue stays a regular issue; mention it once in the summary and suggest `task_issue_type: "issue"`.

6. **If the task is already done** (`[x]`), close the new issue: `glab_close_issue "$ISSUE_NUMBER"`.

7. **Record the issue right away** (so a later failure doesn't cause duplicates):
   ```bash
   write_mapping "$MAPPING_PATH" tasks T012 "$ISSUE_NUMBER" "$ISSUE_URL"
   annotate_task_issue "$TASKS" T012 "$ISSUE_NUMBER"
   ```
   This adds a comment at the end of the line in `tasks.md`:
   ```
   - [ ] T012 [P] [US1] Create User model in src/models/user.py <!-- gitlab:#42 -->
   ```

### Step 6: Summary

Show:
- Number of issues created, with links
- Number of tasks skipped (already present)
- Errors and warnings, if any
- Next step: `__SPECKIT_COMMAND_IMPLEMENT__`, then `__SPECKIT_COMMAND_GITLAB_CLOSE-ISSUES__` to close completed tasks in GitLab.
