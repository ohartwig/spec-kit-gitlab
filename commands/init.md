---
description: "Interactively set up the GitLab configuration"
scripts:
  gitlab-helpers.sh: "../scripts/bash/gitlab-helpers.sh"
---

# Set up the GitLab configuration

Interactively sets up the GitLab integration by asking for all necessary configuration values and writing them to the config file.

## Prerequisites

- `glab` CLI is installed
- spec-kit GitLab extension is installed (`specify extension add --dev ~/spec-kit-gitlab/`)

## User Input

$ARGUMENTS

## Steps

### Step 1: Check whether the glab CLI is available

Check whether `glab` is installed:

```bash
command -v glab
```

If not present, inform the user:
- macOS: `brew install glab`
- Linux: see https://gitlab.com/gitlab-org/cli

### Step 2: Check for an existing configuration

Check whether a configuration file already exists at `.specify/extensions/gitlab/gitlab-config.yml`.

If so, read the existing values and show them to the user. Ask whether they want to update or keep them.

### Step 3: Ask for the GitLab URL

Ask the user for the GitLab server URL:

> **GitLab server URL?**
> e.g. `https://gitlab.example.com` or `https://gitlab.moselwal.io`

Validation:
- Must start with `https://` or `http://`
- No trailing slash

If the `GITLAB_URL` environment variable is set, suggest it as the default.

### Step 4: Ask for the GitLab project

Ask the user for the project path:

> **GitLab project path?**
> e.g. `group/project` or `group/subgroup/project`

If `glab` is already authenticated, try listing the available projects as a helper:

```bash
glab repo list --output json 2>/dev/null | head -20
```

If the `GITLAB_PROJECT` environment variable is set, suggest it as the default.

### Step 5: Check glab authentication

Check whether `glab` is authenticated for the given GitLab server:

```bash
glab auth status --hostname <gitlab-host>
```

If not authenticated, inform the user:

> `glab` is not authenticated for `<gitlab-host>`.
> Please run: `glab auth login --hostname <gitlab-host>`
> Or set the environment variable: `export GITLAB_TOKEN="glpat-..."`

Ask whether to continue anyway (the config can be written even without auth).

### Step 6: Ask for the label configuration

Ask the user for the labels (with defaults):

> **Label for user stories?** (Default: `user-story`)
> **Label for tasks?** (Default: `task`)
> **Label for spec-kit tracking?** (Default: `spec-kit`)
> **Label for feature issues?** (Default: `feature`)

Most users will accept the defaults.

### Step 7: Ask for mapping options

Ask about the mapping options (with defaults):

> **Map priority to a label?** (e.g. P1 → `priority::1`) (Default: yes)
> **Link tasks to story issues?** (Default: yes)
> **Create the feature as a milestone?** (The feature name is used as the GitLab milestone) (Default: yes)
> **Create the feature as a GitLab issue?** (Creates a parent issue per feature) (Default: yes)

### Step 8: Write the configuration file

Create the configuration file at `.specify/extensions/gitlab/gitlab-config.yml`:

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
```

Make sure the `.specify/extensions/gitlab/` directory exists.

### Step 9: Test the connection

If `glab` is authenticated, test the connection:

```bash
glab api projects/:id --repo "<project-path>" 2>/dev/null
```

On success show:
> Connection to `<gitlab-url>` successful. Project `<project>` found.

On failure:
> Connection failed. Please check the URL, project path, and authentication.

### Step 10: Summary and next steps

Show a summary of the written configuration and the next steps:

```
GitLab configuration saved.

  Server:  <url>
  Project: <project>
  Labels:  <speckit-label>, <story-label>, <task-label>

Next steps:
  1. /speckit.spec                      → Create the specification
  2. /speckit.tasks                     → Generate tasks
  3. /speckit.gitlab.stories-to-issues  → Stories as GitLab issues
  4. /speckit.gitlab.tasks-to-issues    → Tasks as GitLab issues

Tip: The config can be updated at any time with /speckit.gitlab.init.
     Local overrides: .specify/extensions/gitlab/gitlab-config.local.yml
```
