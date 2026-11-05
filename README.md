# spec-kit GitLab Extension

GitLab integration for [spec-kit](https://github.com/github/spec-kit): create issues, sync, and post status updates via the `glab` CLI.

Supports gitlab.com and self-hosted GitLab instances.

## Requirements

- **spec-kit** >= 0.12.17 (tested against the 1.3 extension format)
- **glab CLI** >= 1.50.0 ([GitLab CLI](https://gitlab.com/gitlab-org/cli))
- **jq**
- **bash** (macOS, Linux, or Git Bash/WSL on Windows)

## Installation

```bash
# Install and authenticate the glab CLI
brew install glab jq
glab auth login --hostname gitlab.example.com

# Install the extension into your spec-kit project
cd /path/to/your/spec-kit-project
specify extension add gitlab --from https://github.com/ohartwig/spec-kit-gitlab/archive/refs/heads/main.zip

# ...or from a local clone (development mode)
specify extension add --dev ~/spec-kit-gitlab/
```

On install, spec-kit copies the config template to `.specify/extensions/gitlab/gitlab-config.yml` and registers the commands for your coding agent.

## Configuration

The easiest way is the interactive setup command (`speckit.gitlab.init`, see [Invoking the commands](#invoking-the-commands)). It writes `.specify/extensions/gitlab/gitlab-config.yml`:

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
  priority_to_label: true          # Story priority P1/P2/P3 → priority::1/2/3
  feature_to_milestone: true       # Feature directory name as a GitLab milestone
  feature_to_issue: true           # Create the feature as a GitLab issue
  link_tasks_to_stories: true      # Link task issues to story issues
  task_issue_type: "task"          # GitLab type for task issues: "task" or "issue"
```

Configuration is resolved in this order (highest first):

1. Environment variables `GITLAB_URL` and `GITLAB_PROJECT`
2. Local overrides in `.specify/extensions/gitlab/gitlab-config.local.yml` (per key, not committed, kept on reinstall)
3. `.specify/extensions/gitlab/gitlab-config.yml`
4. Built-in defaults

Authentication is handled entirely by `glab` (`glab auth login`, or `GITLAB_TOKEN` with the `api` scope). Never put a token in the config file.

## Invoking the commands

The command names below are the extension's command IDs. How you type them depends on your coding agent, for example `/speckit.gitlab.init` for agents with slash commands, or `/speckit-gitlab-init` for agents that use skills (such as GitHub Copilot's skills layout). See spec-kit's [command invocation reference](https://github.com/github/spec-kit/blob/main/docs/integrations/cli.md#command-invocation).

## Commands

### `speckit.gitlab.init`

Interactive setup of the GitLab configuration. Checks `glab` and `jq`, suggests values from the git remote, tests the connection, and writes the configuration file.

### `speckit.gitlab.feature-to-issue`

Creates a GitLab issue for the current feature and links existing story issues to it. Uses the feature name from `spec.md` as the title and the overview section as the description. Labels: `spec-kit`, `feature`.

### `speckit.gitlab.import-feature`

Imports an existing GitLab issue as a feature. Argument: issue number (`232`, `#232`) or issue URL. Writes the mapping, optionally seeds `spec.md` from the issue description, and links existing stories.

### `speckit.gitlab.stories-to-issues`

Creates GitLab issues for all user stories in `spec.md`. Reads the spec-kit template format `### User Story 1 - Title (Priority: P1)` (the older `### US1: Title [P1]` still works) and sets the labels `spec-kit`, `user-story`, and `priority::N`. New stories are linked to the feature issue, if there is one.

### `speckit.gitlab.tasks-to-issues`

Creates GitLab issues (type *Task* by default) for all tasks in `tasks.md`. Reads the spec-kit format `- [ ] T012 [P] [US1] Description`, where `[P]` marks a parallelizable task and `[US1]` the story. Tasks inherit the priority of their story and are linked to the story issue.

### `speckit.gitlab.close-issues`

Pushes the local completion status to GitLab. Tasks marked `[x]`/`[X]` in `tasks.md` are closed in GitLab, tasks reopened (`[ ]`) are reopened. Stories are closed once all their tasks are complete. Supports `--dry-run`.

### `speckit.gitlab.sync`

Pulls the GitLab issue status into `tasks.md` (closed → `[x]`, open → `[ ]`) and shows the feature issue status. With `--import`, adds GitLab task issues that aren't in `tasks.md` yet. Supports `--dry-run`.

### `speckit.gitlab.status`

Shows an overview of all issues of the feature (task ID, issue number, status, assignee, story progress) and updates `tasks.md`. If local and GitLab status contradict each other, it asks which side wins. `--no-update` only shows the overview.

## Workflow

### Push workflow (local → GitLab)

```
1. speckit.gitlab.init               → Set up the GitLab connection
2. speckit.specify                   → Create spec.md
3. speckit.gitlab.feature-to-issue   → Feature as a GitLab issue
4. speckit.gitlab.stories-to-issues  → Stories as GitLab issues (linked to the feature)
5. speckit.plan, speckit.tasks       → Plan and generate tasks.md
6. speckit.gitlab.tasks-to-issues    → Tasks as GitLab issues (linked to stories)
7. speckit.implement                 → Implement
8. speckit.gitlab.close-issues       → Close completed issues in GitLab
```

### Pull workflow (GitLab → local)

```
1. speckit.specify <issue title>       → Start the feature in spec-kit
2. speckit.gitlab.import-feature 232   → Link the feature to the existing issue
3. speckit.clarify                     → Refine the specification
4. speckit.gitlab.stories-to-issues    → Stories as GitLab issues
5. speckit.plan, speckit.tasks         → Plan and generate tasks
6. speckit.gitlab.tasks-to-issues      → Tasks as GitLab issues
7. speckit.gitlab.sync                 → Pull status changes made in GitLab
```

## Mapping file

The extension keeps a `.gitlab-mapping.yml` in the feature directory, so commands can be run repeatedly without creating duplicates:

```yaml
feature: "#232 https://gitlab.example.com/group/project/-/issues/232"
stories:
  US1: "#10 https://gitlab.example.com/group/project/-/issues/10"
tasks:
  T001: "#42 https://gitlab.example.com/group/project/-/issues/42"
```

Task lines in `tasks.md` also get a `<!-- gitlab:#42 -->` comment. The `feature:` entry is set by `speckit.gitlab.feature-to-issue` (push) or `speckit.gitlab.import-feature` (pull).

## Hooks

- **after_tasks**: after task generation, you're asked whether to create the tasks as GitLab issues.
- **after_implement**: after implementation, you're asked whether to close completed tasks in GitLab.

Both hooks are optional and can be turned off in `.specify/extensions.yml`.

## Development

```bash
bash tests/test-helpers.sh
```

The tests cover config loading, `tasks.md`/`spec.md` parsing, and the mapping file. They run offline. `tests/`, `.github/`, and `CHANGELOG.md` are excluded from installation via `.extensionignore`.

## License

MIT — Moselwal Digitalagentur GmbH
