---
description: "Interactively set up the GitLab configuration"
---

# Set up the GitLab configuration

Interactively sets up the GitLab integration by asking for all necessary configuration values and writing them to the config file.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It may already contain values such as the GitLab URL or project path; use them instead of asking again.

## Prerequisites

- `glab` CLI (>= 1.50) and `jq` are installed
- The spec-kit GitLab extension is installed (`specify extension add --dev /path/to/spec-kit-gitlab`)

## Notes

- Run all commands from the project root.
- The helper functions live in `.specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh`. Shell state may not persist between your tool calls, so `source` the helpers in the same invocation as the functions you call.
- Never write a token into the configuration file.

## Steps

### Step 1: Check the required tools

```bash
command -v glab && glab version
command -v jq
```

If `glab` is missing, tell the user how to install it:
- macOS: `brew install glab`
- Linux/Windows: see https://gitlab.com/gitlab-org/cli#installation

If `jq` is missing: `brew install jq`, `apt-get install jq`, or see https://jqlang.org/download/.

### Step 2: Check for an existing configuration

The configuration lives at `.specify/extensions/gitlab/gitlab-config.yml`. Spec Kit copies the template there when the extension is installed, so the file usually exists but has an empty `url` and `project`.

If it already contains a URL and project, show the current values and ask whether to update or keep them. If the user keeps them, continue with Step 9 (connection test).

### Step 3: Ask for the GitLab URL

> **GitLab server URL?**
> e.g. `https://gitlab.example.com`

Validation:
- Must start with `https://` or `http://`
- Remove a trailing slash

If the `GITLAB_URL` environment variable is set, or the project's git remote points to a GitLab host (`git config --get remote.origin.url`), suggest that as the default.

### Step 4: Ask for the GitLab project

> **GitLab project path?**
> e.g. `group/project` or `group/subgroup/project`

If the git remote points to the same host, suggest the path from the remote URL (without `.git`). If the `GITLAB_PROJECT` environment variable is set, suggest it as the default.

### Step 5: Check glab authentication

```bash
glab auth status --hostname <gitlab-host>
```

`<gitlab-host>` is the host part of the URL (for example `gitlab.example.com`).

If not authenticated, tell the user:

> `glab` is not authenticated for `<gitlab-host>`.
> Run `glab auth login --hostname <gitlab-host>` in your terminal,
> or export a token: `export GITLAB_TOKEN="glpat-..."` (scope: `api`).

Ask whether to continue anyway (the config can be written without auth).

### Step 6: Ask for the label configuration

Ask for the labels (with defaults). Most users accept the defaults:

> **Label for user stories?** (Default: `user-story`)
> **Label for tasks?** (Default: `task`)
> **Label for spec-kit tracking?** (Default: `spec-kit`)
> **Label for feature issues?** (Default: `feature`)

### Step 7: Ask for mapping options

> **Map story priority to a label?** (P1 → `priority::1`) (Default: yes)
> **Link tasks to their story issues?** (Default: yes)
> **Use the feature as a milestone?** (The feature directory name becomes a GitLab milestone) (Default: yes)
> **Create the feature as a GitLab issue?** (A parent issue per feature) (Default: yes)
> **GitLab type for task issues?** `task` or `issue` (Default: `task`; use `issue` if your GitLab version or license doesn't support the task type)

### Step 8: Write the configuration file

Make sure `.specify/extensions/gitlab/` exists, then write `.specify/extensions/gitlab/gitlab-config.yml`:

```yaml
gitlab:
  url: "<entered URL>"
  project: "<entered project path>"

labels:
  story_label: "<entered label>"
  task_label: "<entered label>"
  speckit_label: "<entered label>"
  feature_label: "<entered label>"

mapping:
  priority_to_label: <true/false>
  feature_to_milestone: <true/false>
  feature_to_issue: <true/false>
  link_tasks_to_stories: <true/false>
  task_issue_type: "<task/issue>"
```

### Step 9: Test the connection

If `glab` is authenticated, test the connection:

```bash
source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
load_gitlab_config && glab_check_connection
```

On success (a project URL is printed):
> Connection to `<gitlab-url>` successful. Project `<project>` found.

On failure:
> Connection failed. Please check the URL, project path, and authentication.

### Step 10: Summary and next steps

```
GitLab configuration saved.

  Server:  <url>
  Project: <project>
  Labels:  <speckit-label>, <story-label>, <task-label>, <feature-label>

Next steps:
  1. __SPECKIT_COMMAND_SPECIFY__                   → Create the specification
  2. __SPECKIT_COMMAND_GITLAB_FEATURE-TO-ISSUE__   → Feature as a GitLab issue
  3. __SPECKIT_COMMAND_GITLAB_STORIES-TO-ISSUES__  → Stories as GitLab issues
  4. __SPECKIT_COMMAND_PLAN__ and __SPECKIT_COMMAND_TASKS__ → Plan and generate tasks
  5. __SPECKIT_COMMAND_GITLAB_TASKS-TO-ISSUES__    → Tasks as GitLab issues

Tip: Run __SPECKIT_COMMAND_GITLAB_INIT__ again at any time to change the config.
     Local overrides: .specify/extensions/gitlab/gitlab-config.local.yml
```
