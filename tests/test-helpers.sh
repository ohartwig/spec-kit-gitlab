#!/usr/bin/env bash
# Offline tests for scripts/bash/gitlab-helpers.sh (no GitLab access needed).
# Run: bash tests/test-helpers.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/bash/gitlab-helpers.sh
source "$ROOT/scripts/bash/gitlab-helpers.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAIL_LOG="$TMP/failures"
: > "$FAIL_LOG"

read_lines() {
  # read_lines <array-name> < input   (mapfile replacement for bash 3.2)
  local __line __i=0
  eval "$1=()"
  while IFS= read -r __line; do
    eval "$1[$__i]=\"\$__line\""
    __i=$((__i + 1))
  done
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $msg"
  else
    echo "FAIL - $msg"
    echo "       expected: $(printf '%q' "$expected")"
    echo "       actual:   $(printf '%q' "$actual")"
    echo "$msg" >> "$FAIL_LOG"  # a file, so failures in subshells count too
  fi
}

# --- config -----------------------------------------------------------------
mkdir -p "$TMP/cfg"
cat > "$TMP/cfg/gitlab-config.yml" << 'YAML'
gitlab:
  url: "https://gitlab.example.com/"   # trailing slash is removed
  project: "group/sub/project"
labels:
  story_label: "story"
mapping:
  priority_to_label: false
YAML
cat > "$TMP/cfg/gitlab-config.local.yml" << 'YAML'
labels:
  story_label: "local-story"
YAML
(
  unset GITLAB_URL GITLAB_PROJECT
  load_gitlab_config "$TMP/cfg/gitlab-config.yml"
  assert_eq "https://gitlab.example.com" "$GITLAB_URL" "url is read and trailing slash stripped"
  assert_eq "group/sub/project" "$GITLAB_PROJECT" "project is read"
  assert_eq "group%2Fsub%2Fproject" "$GITLAB_PROJECT_ENC" "project path is URL-encoded"
  assert_eq "gitlab.example.com" "$GITLAB_HOSTNAME" "hostname is derived"
  assert_eq "local-story" "$GITLAB_STORY_LABEL" "local override wins per key"
  assert_eq "task" "$GITLAB_TASK_LABEL" "defaults apply for missing keys"
  assert_eq "false" "$GITLAB_PRIORITY_TO_LABEL" "booleans are read"
  assert_eq "task" "$GITLAB_TASK_ISSUE_TYPE" "task_issue_type defaults to task"
)

cat > "$TMP/cfg/placeholder-config.yml" << 'YAML'
gitlab:
  url: "${GITLAB_URL}"
  project: "${GITLAB_PROJECT}"
YAML
(
  unset GITLAB_URL GITLAB_PROJECT
  if load_gitlab_config "$TMP/cfg/placeholder-config.yml" 2>/dev/null; then
    assert_eq "fail" "ok" "placeholder config without env must fail"
  else
    assert_eq "1" "1" "placeholder config without env fails"
  fi
  GITLAB_URL="https://env.example.com" GITLAB_PROJECT="env/proj" load_gitlab_config "$TMP/cfg/placeholder-config.yml"
  assert_eq "env/proj" "$GITLAB_PROJECT" "environment variables override placeholders"
)

# --- tasks.md parsing -------------------------------------------------------
cat > "$TMP/tasks.md" << 'MD'
# Tasks

- [ ] T001 Create project structure per implementation plan
- [X] T002 [P] Configure linting and formatting tools
- [ ] T010 [P] [US1] Contract test for endpoint in tests/contract/test_x.py <!-- gitlab:#42 -->
- [x] T1000 [US2] Implement service (depends on T012)
- [ ] T003 [P1] [US1] Legacy priority marker
Not a task line T004
MD
read_lines TASKS < <(parse_tasks "$TMP/tasks.md")
assert_eq "5" "${#TASKS[@]}" "parse_tasks finds 5 tasks"
assert_eq $'T001\topen\t\t\tno\t\tCreate project structure per implementation plan' "${TASKS[0]}" "plain task"
assert_eq $'T002\tdone\t\t\tyes\t\tConfigure linting and formatting tools' "${TASKS[1]}" "[X] and [P] markers"
assert_eq $'T010\topen\tUS1\t\tyes\t42\tContract test for endpoint in tests/contract/test_x.py' "${TASKS[2]}" "story marker and gitlab comment"
assert_eq $'T1000\tdone\tUS2\t\tno\t\tImplement service (depends on T012)' "${TASKS[3]}" "four-digit task ID"
assert_eq $'T003\topen\tUS1\tP1\tno\t\tLegacy priority marker' "${TASKS[4]}" "legacy [P1] priority marker"

set_task_checkbox "$TMP/tasks.md" T001 done
set_task_checkbox "$TMP/tasks.md" T002 open
annotate_task_issue "$TMP/tasks.md" T001 7
annotate_task_issue "$TMP/tasks.md" T001 7
annotate_task_issue "$TMP/tasks.md" T010 99
assert_eq "- [x] T001 Create project structure per implementation plan <!-- gitlab:#7 -->" "$(grep 'T001 ' "$TMP/tasks.md")" "checkbox set and annotated once"
assert_eq "- [ ] T002 [P] Configure linting and formatting tools" "$(grep 'T002 ' "$TMP/tasks.md")" "checkbox cleared"
assert_eq "1" "$(grep -c 'gitlab:#' <(grep 'T010 ' "$TMP/tasks.md"))" "existing annotation is kept"
assert_eq "- [x] T1000 [US2] Implement service (depends on T012)" "$(grep 'T1000 ' "$TMP/tasks.md")" "T100x prefix does not collide"

# --- spec.md parsing --------------------------------------------------------
cat > "$TMP/spec.md" << 'MD'
## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log in with SSO (Priority: P1)
### User Story 2 - Reset password (Priority: P2)
### US3: Legacy story [P3]
### User Story 4 – Em dash title (Priority: P2)
### Edge Cases
MD
read_lines STORIES < <(parse_stories "$TMP/spec.md")
assert_eq "4" "${#STORIES[@]}" "parse_stories finds 4 stories"
assert_eq $'US1\tP1\tLog in with SSO' "${STORIES[0]}" "template story format"
assert_eq $'US3\tP3\tLegacy story' "${STORIES[2]}" "legacy story format"
assert_eq $'US4\tP2\tEm dash title' "${STORIES[3]}" "en dash separator"

# --- mapping file -----------------------------------------------------------
mkdir -p "$TMP/feature"
MAP="$(init_mapping_file "$TMP/feature")"
write_mapping "$MAP" stories US1 10 "https://gitlab.example.com/g/p/-/issues/10"
write_mapping "$MAP" tasks T001 42 "https://gitlab.example.com/g/p/-/issues/42"
write_mapping "$MAP" tasks T002 43
write_mapping "$MAP" tasks T001 44
write_feature_mapping "$MAP" 232 "https://gitlab.example.com/g/p/-/issues/232"
assert_eq "#10 https://gitlab.example.com/g/p/-/issues/10" "$(read_mapping "$MAP" stories US1)" "story mapping"
assert_eq "#44" "$(read_mapping "$MAP" tasks T001)" "task mapping is updated in place"
assert_eq "#43" "$(read_mapping "$MAP" tasks T002)" "second task mapping"
assert_eq "" "$(read_mapping "$MAP" stories T001)" "lookups are section-scoped"
assert_eq "232" "$(extract_feature_issue_number "$(read_feature_mapping "$MAP")")" "feature mapping"
assert_eq $'T001\t#44\nT002\t#43' "$(list_mapping_ids "$MAP" tasks)" "list_mapping_ids"
if command -v python3 >/dev/null && python3 -c 'import yaml' 2>/dev/null; then
  assert_eq "ok" "$(python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); print("ok" if d["tasks"]["T001"]=="#44" and d["stories"]["US1"].startswith("#10") else d)' "$MAP")" "mapping file is valid YAML"
fi

# --- misc -------------------------------------------------------------------
OUT=$'Creating issue in group/project\n#42 T001: Something (now)\n https://gitlab.example.com/group/project/-/issues/42\n'
assert_eq "https://gitlab.example.com/group/project/-/issues/42" "$(extract_issue_url "$OUT")" "extract_issue_url"
assert_eq "42" "$(extract_issue_number "$OUT")" "extract_issue_number"
assert_eq "priority::2" "$(priority_to_label P2)" "priority_to_label"
assert_eq "P3" "$(label_to_priority priority::3)" "label_to_priority"

echo
FAILURES="$(wc -l < "$FAIL_LOG" | tr -d ' ')"
if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All tests passed"
