# Changelog

All notable changes to this extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-05

Brings the extension up to date with spec-kit 1.3 and the current glab CLI.

### Changed

- Requires spec-kit `>=0.12.17` and glab `>=1.50.0`; `jq` is now listed as a required tool.
- Command frontmatter uses the standard `scripts: {sh, ps}` keys with the `{SCRIPT}` placeholder. The old custom keys (`gitlab-helpers.sh: ...`) and `{SCRIPT:name}` placeholders made the registrar fail ("No runnable script variant") and were never substituted.
- The feature directory is resolved with `check-prerequisites --json --paths-only`, so commands no longer require `plan.md` and use the correct `.specify/scripts/bash/` path.
- Commands reference each other with `__SPECKIT_COMMAND_*__` tokens instead of hard-coded `/speckit.*` invocations, so they render correctly for skills-based agents. `/speckit.spec` (which doesn't exist) is replaced with the specify command.
- Task parsing follows the spec-kit `tasks.md` format: `[P]` is the parallel marker, `[US1]` the story, and `[X]` counts as done. A task inherits its priority from its story. Legacy `[P1]` markers still work.
- Story parsing follows the spec-kit `spec.md` format `### User Story 1 - Title (Priority: P1)`. The legacy `### US1: Title [P1]` format still works.
- Task IDs with four or more digits (`T1000`) are supported.
- The local override `gitlab-config.local.yml` (or `local-config.yml`) now overrides individual keys instead of replacing the whole configuration.
- The config template uses empty values instead of `${GITLAB_URL}` placeholders, since spec-kit copies it into the project on install and doesn't expand placeholders.

### Added

- Optional `after_implement` hook that offers to close completed tasks in GitLab.
- `mapping.task_issue_type` (`task` or `issue`) to choose the GitLab type of task issues.
- Helpers `parse_tasks`, `parse_stories`, `list_mapping_ids`, `set_task_checkbox`, `annotate_task_issue`, `glab_set_issue_type`, `glab_check_connection`, and `label_to_priority`.
- `--dry-run` for close-issues and sync, `--no-update` for status.
- Offline tests (`tests/test-helpers.sh`) and a CI workflow.
- `.extensionignore`, so tests and CI files aren't copied into projects.

### Fixed

- `glab issue create --type` doesn't exist; the task type is now set through the API after creation.
- `glab issue relation` doesn't exist; issues are linked with `--linked-issues` on creation or through the issue links API.
- `glab issue list --state all` doesn't exist and only returned the first 30 issues; issues are now listed through the API with pagination.
- `glab api` has no `--repo` flag; API calls use `--hostname` and the URL-encoded project path, so they work outside a clone of the GitLab project and with self-hosted instances.
- The mapping file was written as invalid YAML (`stories: {}` followed by entries).
- Sourcing the helper script no longer turns on `set -euo pipefail` in the caller's shell.
- YAML parsing works with BSD/macOS `sed` and ignores trailing comments.

## [1.0.0]

### Added

- Initial release: init, feature-to-issue, import-feature, stories-to-issues, tasks-to-issues, close-issues, sync, and status commands.
