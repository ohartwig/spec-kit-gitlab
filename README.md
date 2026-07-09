# spec-kit GitLab Extension

GitLab integration for [spec-kit](https://github.com/github/spec-kit): create issues, sync, and post status updates via the `glab` CLI.

Supports self-hosted GitLab instances.

## Requirements

- **spec-kit** >= 0.1.0
- **glab CLI** >= 1.0.0 ([GitLab CLI](https://gitlab.com/gitlab-org/cli))

## Installation

```bash
# Install and authenticate the glab CLI
brew install glab
glab auth login --hostname gitlab.example.com

# Install the extension (development mode)
cd /path/to/your/spec-kit-project
specify extension add --dev ~/spec-kit-gitlab/
```

## Configuration

The easiest way is via the interactive setup:

```bash
/speckit.gitlab.init
```

This creates the configuration file at `.specify/extensions/gitlab/gitlab-config.yml`:

```yaml
gitlab:
  url: "https://gitlab.example.com"
  project: "group/project"

labels:
  story_label: "user-story"
  task_label: "task"
  speckit_label: "spec-kit"
  feature_label: "feature"

mapping:
  priority_to_label: true          # P1/P2/P3 → priority::1/2/3
  feature_to_milestone: true       # Feature name as a GitLab milestone
  feature_to_issue: true           # Create the feature as a GitLab issue
  link_tasks_to_stories: true      # Link tasks to story issues
```

Alternatively, via environment variables:

```bash
export GITLAB_URL="https://gitlab.example.com"
export GITLAB_PROJECT="group/project"
export GITLAB_TOKEN="glpat-xxxxxxxxxxxx"
```

## Commands

### `/speckit.gitlab.init`

Interactive setup of the GitLab configuration. Checks the `glab` installation, tests the connection, and writes the configuration file.

### `/speckit.gitlab.feature-to-issue`

Creates a GitLab issue for the current feature and links existing story issues to it. Uses the feature directory name as the title and the context from `spec.md` as the description. Labels: `spec-kit`, `feature`.

### `/speckit.gitlab.import-feature`

Imports an existing GitLab issue as a feature. Argument: issue number (e.g. `232` or `#232`). Writes the mapping, optionally creates a `spec.md` from the issue description, and links existing stories.

### `/speckit.gitlab.stories-to-issues`

Creates GitLab issues for all user stories from `spec.md`. Expects the format `### US1: Title [P1]` and automatically assigns labels (`spec-kit`, `user-story`, `priority::X`). Automatically links new stories to the feature issue (if one exists).

### `/speckit.gitlab.tasks-to-issues`

Creates GitLab issues (Type: Task) for all tasks from `tasks.md`. Expects the format `- [ ] T001 [P1] [US1] Description`. Automatically links tasks to their story issues.

### `/speckit.gitlab.close-issues`

Syncs the local completion status to GitLab. Tasks marked `[x]` in `tasks.md` are closed in GitLab; tasks reopened (`[ ]`) are reopened. Stories are automatically closed once all their tasks are complete.

### `/speckit.gitlab.sync`

Syncs GitLab issue status into the local `tasks.md` files. Updates checkboxes based on issue status (open/closed). Shows the feature issue status (if one exists). Optional: imports new GitLab issues with `--import`.

### `/speckit.gitlab.status`

Shows an overview of all GitLab issues with their current status (task ID, issue number, status, assignee) and updates `tasks.md`. Shows the feature issue status at the top of the overview. Includes progress statistics (open, closed, percent).

## Workflow

### Push workflow (Local → GitLab)

```
1. /speckit.gitlab.init              → Set up the GitLab connection
2. /speckit.spec                     → Create spec.md
3. /speckit.gitlab.feature-to-issue  → Create the feature as a GitLab issue
4. /speckit.tasks                    → Generate tasks.md
5. /speckit.gitlab.stories-to-issues → Stories as GitLab issues (linked to the feature)
6. /speckit.gitlab.tasks-to-issues   → Tasks as GitLab issues (linked to stories)
7. /speckit.gitlab.close-issues      → Close completed issues in GitLab
8. /speckit.gitlab.status            → Sync status
```

### Pull workflow (GitLab → Local)

```
1. /speckit.gitlab.import-feature 232  → Import an existing issue as a feature
2. /speckit.spec                       → Create/refine the specification
3. /speckit.tasks                      → Generate tasks
4. /speckit.gitlab.stories-to-issues   → Stories as GitLab issues
5. /speckit.gitlab.tasks-to-issues     → Tasks as GitLab issues
```

## Mapping file

The extension maintains a `.gitlab-mapping.yml` in the feature directory to ensure idempotency:

```yaml
feature: "#232 https://gitlab.example.com/group/project/-/issues/232"
stories:
  US1: "#10 https://gitlab.example.com/group/project/-/issues/10"
tasks:
  T001: "#42 https://gitlab.example.com/group/project/-/issues/42"
```

The `feature:` field is set by `/speckit.gitlab.feature-to-issue` (push) or `/speckit.gitlab.import-feature` (pull). Stories are automatically linked to the feature issue.

This lets commands be run multiple times without creating duplicates.

## Hook

After `/speckit.tasks`, you're automatically asked whether tasks should be created as GitLab issues.

## License

MIT — Moselwal Digitalagentur GmbH
