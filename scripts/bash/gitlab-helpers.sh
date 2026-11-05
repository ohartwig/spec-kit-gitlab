#!/usr/bin/env bash
# gitlab-helpers.sh - Shared helper functions for the spec-kit GitLab extension
#
# Usage (from the project root):
#   source .specify/extensions/gitlab/scripts/bash/gitlab-helpers.sh
#   load_gitlab_config
#
# This file is meant to be sourced. It deliberately does not call `set -e`,
# `set -u` or `set -o pipefail`, so it doesn't change the options of the
# calling shell.
#
# Requirements: bash, glab (>= 1.50), jq

# Variables set here are read by the commands that source this file.
# shellcheck disable=SC2034

GITLAB_EXT_DIR="${GITLAB_EXT_DIR:-.specify/extensions/gitlab}"
GITLAB_CONFIG_FILE="${GITLAB_CONFIG_FILE:-$GITLAB_EXT_DIR/gitlab-config.yml}"

# ============================================================================
# Simple YAML reading (flat "key: value" pairs, nested one level deep)
# ============================================================================

_yaml_value() {
  # _yaml_value <file> <key>
  # Prints the first value for <key> (anywhere in the file), without quotes
  # and without trailing comments.
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  grep -E "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 \
    | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//" \
    | sed -E 's/[[:space:]]+#.*$//' \
    | sed -E 's/^"(.*)"$/\1/' \
    | sed -E "s/^'(.*)'\$/\\1/" \
    | sed -E 's/[[:space:]]+$//'
}

_config_value() {
  # _config_value <key>
  # Looks the key up in the local override first, then in the project config.
  local key="$1"
  local value=""
  local file
  for file in "${GITLAB_CONFIG_LOCAL_FILES[@]}" "$GITLAB_CONFIG_FILE"; do
    value="$(_yaml_value "$file" "$key")"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 0
}

_is_placeholder() {
  # Empty or an unresolved "${...}" placeholder
  [[ -z "$1" || "$1" =~ ^\$\{.*\}$ ]]
}

# ============================================================================
# Load configuration
# ============================================================================

load_gitlab_config() {
  # Precedence (highest first):
  #   1. Environment variables (GITLAB_URL, GITLAB_PROJECT)
  #   2. Local override (gitlab-config.local.yml or local-config.yml, gitignored)
  #   3. Project config (.specify/extensions/gitlab/gitlab-config.yml)
  #   4. Built-in defaults
  if [[ -n "${1:-}" ]]; then
    GITLAB_CONFIG_FILE="$1"
  fi
  local config_dir
  config_dir="$(dirname "$GITLAB_CONFIG_FILE")"
  GITLAB_CONFIG_LOCAL_FILES=(
    "${GITLAB_CONFIG_FILE%.yml}.local.yml"
    "$config_dir/local-config.yml"
  )

  if [[ ! -f "$GITLAB_CONFIG_FILE" ]]; then
    local f found=false
    for f in "${GITLAB_CONFIG_LOCAL_FILES[@]}"; do
      [[ -f "$f" ]] && found=true
    done
    if [[ "$found" != true && -z "${GITLAB_URL:-}" ]]; then
      echo "ERROR: GitLab configuration not found: $GITLAB_CONFIG_FILE" >&2
      echo "Run the GitLab init command (speckit.gitlab.init) to create it." >&2
      return 1
    fi
  fi

  local url project
  url="$(_config_value url)"
  project="$(_config_value project)"
  _is_placeholder "$url" && url=""
  _is_placeholder "$project" && project=""

  GITLAB_URL="${GITLAB_URL:-$url}"
  GITLAB_URL="${GITLAB_URL%/}"
  GITLAB_PROJECT="${GITLAB_PROJECT:-$project}"
  GITLAB_PROJECT="${GITLAB_PROJECT#/}"
  GITLAB_PROJECT="${GITLAB_PROJECT%/}"

  GITLAB_STORY_LABEL="$(_config_value story_label)"
  GITLAB_TASK_LABEL="$(_config_value task_label)"
  GITLAB_SPECKIT_LABEL="$(_config_value speckit_label)"
  GITLAB_FEATURE_LABEL="$(_config_value feature_label)"
  GITLAB_PRIORITY_TO_LABEL="$(_config_value priority_to_label)"
  GITLAB_LINK_TASKS="$(_config_value link_tasks_to_stories)"
  GITLAB_FEATURE_TO_MILESTONE="$(_config_value feature_to_milestone)"
  GITLAB_FEATURE_TO_ISSUE="$(_config_value feature_to_issue)"
  GITLAB_TASK_ISSUE_TYPE="$(_config_value task_issue_type)"

  # Defaults
  GITLAB_STORY_LABEL="${GITLAB_STORY_LABEL:-user-story}"
  GITLAB_TASK_LABEL="${GITLAB_TASK_LABEL:-task}"
  GITLAB_SPECKIT_LABEL="${GITLAB_SPECKIT_LABEL:-spec-kit}"
  GITLAB_FEATURE_LABEL="${GITLAB_FEATURE_LABEL:-feature}"
  GITLAB_PRIORITY_TO_LABEL="${GITLAB_PRIORITY_TO_LABEL:-true}"
  GITLAB_LINK_TASKS="${GITLAB_LINK_TASKS:-true}"
  GITLAB_FEATURE_TO_MILESTONE="${GITLAB_FEATURE_TO_MILESTONE:-true}"
  GITLAB_FEATURE_TO_ISSUE="${GITLAB_FEATURE_TO_ISSUE:-true}"
  GITLAB_TASK_ISSUE_TYPE="${GITLAB_TASK_ISSUE_TYPE:-task}"

  # Validation
  if [[ -z "$GITLAB_URL" ]]; then
    echo "ERROR: GITLAB_URL is not configured. Set gitlab.url in $GITLAB_CONFIG_FILE or export GITLAB_URL." >&2
    return 1
  fi
  if [[ ! "$GITLAB_URL" =~ ^https?:// ]]; then
    echo "ERROR: GITLAB_URL must start with https:// or http:// (got: $GITLAB_URL)" >&2
    return 1
  fi
  if [[ -z "$GITLAB_PROJECT" ]]; then
    echo "ERROR: GITLAB_PROJECT is not configured. Set gitlab.project in $GITLAB_CONFIG_FILE or export GITLAB_PROJECT." >&2
    return 1
  fi

  GITLAB_HOSTNAME="$(gitlab_hostname)"
  GITLAB_PROJECT_ENC="$(urlencode "$GITLAB_PROJECT")"
  GITLAB_PROJECT_ID=""

  export GITLAB_URL GITLAB_PROJECT GITLAB_HOSTNAME GITLAB_PROJECT_ENC
}

# ============================================================================
# Utilities
# ============================================================================

urlencode() {
  printf '%s' "$1" | jq -sRr @uri
}

gitlab_hostname() {
  # https://gitlab.example.com:8443/ → gitlab.example.com:8443
  local host="${GITLAB_URL#*://}"
  printf '%s' "${host%%/*}"
}

require_tools() {
  local missing=()
  command -v glab >/dev/null 2>&1 || missing+=("glab")
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required tools: ${missing[*]}" >&2
    return 1
  fi
}

# ============================================================================
# glab wrappers
# ============================================================================

glab_cmd() {
  # Runs a `glab` subcommand that supports --repo (issue, mr, ...) against the
  # configured project. The full project URL selects the host as well.
  glab "$@" --repo "$GITLAB_URL/$GITLAB_PROJECT"
}

glab_api() {
  # Runs `glab api` against the configured host. `glab api` has no --repo
  # flag, so endpoints must reference the project explicitly, e.g.
  # "projects/$GITLAB_PROJECT_ENC/issues".
  glab api --hostname "$GITLAB_HOSTNAME" "$@"
}

glab_project_id() {
  # Numeric project ID (cached)
  if [[ -z "${GITLAB_PROJECT_ID:-}" ]]; then
    GITLAB_PROJECT_ID="$(glab_api "projects/$GITLAB_PROJECT_ENC" 2>/dev/null | jq -r '.id // empty')"
  fi
  [[ -n "$GITLAB_PROJECT_ID" ]] && printf '%s' "$GITLAB_PROJECT_ID"
}

glab_check_connection() {
  # Prints the project's web URL on success
  glab_api "projects/$GITLAB_PROJECT_ENC" 2>/dev/null | jq -r '.web_url // empty'
}

glab_create_issue() {
  # glab_create_issue <title> [description] [labels] [milestone] [linked-iids]
  # Prints glab's output (contains the issue URL).
  local title="$1"
  local description="${2:-}"
  local labels="${3:-}"
  local milestone="${4:-}"
  local linked="${5:-}"

  local args=(issue create --title "$title" --yes)

  # Always pass a description: without one glab may open an editor/prompt.
  args+=(--description "${description:-Created by spec-kit.}")
  if [[ -n "$labels" ]]; then
    args+=(--label "$labels")
  fi
  if [[ -n "$milestone" ]]; then
    args+=(--milestone "$milestone")
  fi
  if [[ -n "$linked" ]]; then
    args+=(--linked-issues "$linked" --link-type "relates_to")
  fi

  glab_cmd "${args[@]}" 2>&1
}

glab_set_issue_type() {
  # glab_set_issue_type <iid> <type>   (issue | task | incident | test_case)
  local iid="$1"
  local type="${2:-issue}"
  [[ "$type" == "issue" ]] && return 0
  if ! glab_api --method PUT "projects/$GITLAB_PROJECT_ENC/issues/$iid" \
      -f "issue_type=$type" --silent 2>/dev/null; then
    echo "WARN: Could not set type '$type' on issue #$iid; it stays a regular issue." >&2
    return 1
  fi
}

glab_list_issues() {
  # glab_list_issues [labels] [state]
  # All issues (all pages) as one JSON array. state: all | opened | closed
  local labels="${1:-$GITLAB_SPECKIT_LABEL}"
  local state="${2:-all}"

  glab_api --paginate --method GET "projects/$GITLAB_PROJECT_ENC/issues" \
    -f "labels=$labels" -f "state=$state" -f "per_page=100" 2>/dev/null \
    | jq -s 'flatten' 2>/dev/null || echo "[]"
}

glab_view_issue() {
  # JSON of a single issue (iid, title, state, labels, assignees, web_url, ...)
  local iid="$1"
  glab_api "projects/$GITLAB_PROJECT_ENC/issues/$iid" 2>/dev/null
}

glab_issue_state() {
  # Prints "opened" or "closed"
  glab_view_issue "$1" | jq -r '.state // empty'
}

glab_add_relation() {
  # glab_add_relation <source-iid> <target-iid> [link_type]
  # Creates an issue link (default: relates_to). Already existing links are
  # ignored.
  local source_iid="$1"
  local target_iid="$2"
  local link_type="${3:-relates_to}"
  local project_id
  project_id="$(glab_project_id)" || true
  [[ -z "$project_id" ]] && project_id="$GITLAB_PROJECT"

  local out
  if out="$(glab_api --method POST "projects/$GITLAB_PROJECT_ENC/issues/$source_iid/links" \
      -f "target_project_id=$project_id" \
      -f "target_issue_iid=$target_iid" \
      -f "link_type=$link_type" 2>&1)"; then
    return 0
  fi
  if printf '%s' "$out" | grep -qi "already"; then
    return 0
  fi
  echo "WARN: Could not link #$source_iid to #$target_iid: $out" >&2
  return 1
}

glab_close_issue() {
  glab_cmd issue close "$1" 2>&1
}

glab_reopen_issue() {
  glab_cmd issue reopen "$1" 2>&1
}

# ============================================================================
# Mapping file management
# ============================================================================

MAPPING_FILE=".gitlab-mapping.yml"

init_mapping_file() {
  local feature_dir="$1"
  local mapping_path="$feature_dir/$MAPPING_FILE"

  if [[ ! -f "$mapping_path" ]]; then
    cat > "$mapping_path" << 'YAML'
# GitLab Issue Mapping - automatically generated by the spec-kit GitLab extension
# Format: spec-kit ID → GitLab issue number and URL
feature: ""
stories: {}
tasks: {}
YAML
  fi
  echo "$mapping_path"
}

_ensure_section() {
  # Makes sure "<section>:" exists as a block mapping header (not "{}").
  local mapping_path="$1"
  local section="$2"
  if grep -qE "^${section}:[[:space:]]*\{\}[[:space:]]*$" "$mapping_path"; then
    sed -i.bak -E "s/^${section}:[[:space:]]*\{\}[[:space:]]*$/${section}:/" "$mapping_path"
    rm -f "${mapping_path}.bak"
  elif ! grep -qE "^${section}:" "$mapping_path"; then
    printf '%s:\n' "$section" >> "$mapping_path"
  fi
}

read_mapping() {
  # read_mapping <mapping-path> <stories|tasks> <id>
  # Prints the stored value, e.g. "#42 https://.../issues/42"
  local mapping_path="$1"
  local section="$2"
  local id="$3"

  [[ -f "$mapping_path" ]] || return 1

  local in_section=false line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^${section}: ]]; then
      in_section=true
      continue
    fi
    if [[ "$in_section" == true ]]; then
      if [[ "$line" =~ ^[^[:space:]#] ]]; then
        break  # The next section begins
      fi
      if [[ "$line" =~ ^[[:space:]]+${id}:[[:space:]]*(.*)$ ]]; then
        local value="${BASH_REMATCH[1]}"
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"
        printf '%s\n' "$value"
        return 0
      fi
    fi
  done < "$mapping_path"

  return 1
}

list_mapping_ids() {
  # list_mapping_ids <mapping-path> <stories|tasks>
  # Prints "ID<TAB>value" for every entry of the section.
  local mapping_path="$1"
  local section="$2"
  [[ -f "$mapping_path" ]] || return 0

  local in_section=false line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^${section}: ]]; then
      in_section=true
      continue
    fi
    if [[ "$in_section" == true ]]; then
      [[ "$line" =~ ^[^[:space:]#] ]] && break
      if [[ "$line" =~ ^[[:space:]]+([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
        local value="${BASH_REMATCH[2]}"
        value="${value#\"}"; value="${value%\"}"
        printf '%s\t%s\n' "${BASH_REMATCH[1]}" "$value"
      fi
    fi
  done < "$mapping_path"
}

write_mapping() {
  # write_mapping <mapping-path> <stories|tasks> <id> <issue-number> [issue-url]
  local mapping_path="$1"
  local section="$2"
  local id="$3"
  local issue_number="$4"
  local issue_url="${5:-}"

  if [[ ! -f "$mapping_path" ]]; then
    init_mapping_file "$(dirname "$mapping_path")" > /dev/null
  fi
  _ensure_section "$mapping_path" "$section"

  local entry="  ${id}: \"#${issue_number}"
  if [[ -n "$issue_url" ]]; then
    entry+=" ${issue_url}"
  fi
  entry+="\""

  local tmp="${mapping_path}.tmp"
  local in_section=false done=false line
  : > "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$done" == false ]]; then
      if [[ "$line" =~ ^${section}: ]]; then
        in_section=true
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi
      if [[ "$in_section" == true ]]; then
        if [[ "$line" =~ ^[[:space:]]+${id}: ]]; then
          printf '%s\n' "$entry" >> "$tmp"   # update existing entry
          done=true
          continue
        fi
        if [[ "$line" =~ ^[^[:space:]#] ]]; then
          printf '%s\n' "$entry" >> "$tmp"   # append at the end of the section
          done=true
          in_section=false
        fi
      fi
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$mapping_path"
  if [[ "$done" == false ]]; then
    printf '%s\n' "$entry" >> "$tmp"
  fi
  mv "$tmp" "$mapping_path"
}

read_feature_mapping() {
  local mapping_path="$1"
  [[ -f "$mapping_path" ]] || return 1

  local value
  value="$(_yaml_value "$mapping_path" feature)"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  return 1
}

write_feature_mapping() {
  local mapping_path="$1"
  local issue_number="$2"
  local issue_url="${3:-}"

  if [[ ! -f "$mapping_path" ]]; then
    init_mapping_file "$(dirname "$mapping_path")" > /dev/null
  fi

  local entry="feature: \"#${issue_number}"
  if [[ -n "$issue_url" ]]; then
    entry+=" ${issue_url}"
  fi
  entry+="\""

  if grep -qE '^feature:' "$mapping_path" 2>/dev/null; then
    sed -i.bak "s|^feature:.*|${entry}|" "$mapping_path"
  else
    sed -i.bak "/^stories:/i\\
${entry}
" "$mapping_path"
  fi
  rm -f "${mapping_path}.bak"
}

extract_mapping_issue_number() {
  # "#42 https://..." or "#42" → 42
  printf '%s' "$1" | grep -oE '#[0-9]+' | head -1 | tr -d '#'
}

extract_feature_issue_number() {
  extract_mapping_issue_number "$1"
}

# ============================================================================
# Extract the issue URL / number from glab output
# ============================================================================

extract_issue_url() {
  printf '%s' "$1" | grep -oE 'https?://[^[:space:]]+/-/issues/[0-9]+|https?://[^[:space:]]+/issues/[0-9]+' | head -1
}

extract_issue_number() {
  printf '%s' "$1" | grep -oE '/issues/[0-9]+' | head -1 | grep -oE '[0-9]+'
}

# ============================================================================
# Priority mapping
# ============================================================================

priority_to_label() {
  local priority="$1"
  if [[ "$priority" =~ ^[Pp]([0-9]+)$ ]]; then
    echo "priority::${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

label_to_priority() {
  # priority::2 → P2
  local label="$1"
  if [[ "$label" =~ ^priority::([0-9]+)$ ]]; then
    echo "P${BASH_REMATCH[1]}"
  fi
}

# ============================================================================
# Milestone management
# ============================================================================

get_feature_name() {
  # Feature name = name of the feature directory (e.g. 001-user-auth)
  basename "$1"
}

glab_find_milestone() {
  # Looks up an active milestone by title, prints its ID
  local title="$1"
  glab_api --method GET "projects/$GITLAB_PROJECT_ENC/milestones" \
    -f "title=$title" 2>/dev/null | jq -r '.[0].id // empty' 2>/dev/null || true
}

glab_create_milestone() {
  local title="$1"
  local description="${2:-Automatically created by spec-kit for feature: $title}"
  glab_api --method POST "projects/$GITLAB_PROJECT_ENC/milestones" \
    -f "title=$title" -f "description=$description" 2>/dev/null \
    | jq -r '.id // empty' 2>/dev/null
}

glab_ensure_milestone() {
  # Finds or creates a milestone, prints its title (for --milestone)
  local feature_name="$1"

  local milestone_id
  milestone_id="$(glab_find_milestone "$feature_name")"

  if [[ -z "$milestone_id" ]]; then
    milestone_id="$(glab_create_milestone "$feature_name")"
    if [[ -n "$milestone_id" ]]; then
      echo "Milestone '$feature_name' created (ID: $milestone_id)" >&2
    else
      echo "WARN: Could not create milestone '$feature_name'" >&2
      return 1
    fi
  fi

  echo "$feature_name"
}

# ============================================================================
# spec-kit artifact parsing
# ============================================================================

parse_tasks() {
  # parse_tasks <tasks.md>
  # Prints one line per task: ID<TAB>STATUS<TAB>STORY<TAB>PRIORITY<TAB>PARALLEL<TAB>ISSUE<TAB>DESCRIPTION
  #   STATUS:   open | done
  #   STORY:    e.g. US1 (empty if none)
  #   PRIORITY: e.g. P1, only from a legacy "[P1]" marker (empty otherwise)
  #   PARALLEL: yes | no ("[P]" marker)
  #   ISSUE:    GitLab IID from a "<!-- gitlab:#42 -->" comment (empty if none)
  local tasks_file="$1"
  [[ -f "$tasks_file" ]] || return 1

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+\[([ xX])\][[:space:]]+(T[0-9]{3,})[[:space:]]*(.*)$ ]] || continue
    local mark="${BASH_REMATCH[1]}" id="${BASH_REMATCH[2]}" rest="${BASH_REMATCH[3]}"
    local status="open" story="" priority="" parallel="no" issue=""
    [[ "$mark" == "x" || "$mark" == "X" ]] && status="done"

    if [[ "$rest" =~ \<\!--[[:space:]]*gitlab:#([0-9]+)[[:space:]]*--\> ]]; then
      issue="${BASH_REMATCH[1]}"
      rest="$(printf '%s' "$rest" | sed -E 's/[[:space:]]*<!--[[:space:]]*gitlab:#[0-9]+[[:space:]]*-->//')"
    fi

    # Leading markers: [P], [P1], [US1] in any order
    while [[ "$rest" =~ ^\[([A-Za-z0-9]+)\][[:space:]]*(.*)$ ]]; do
      local marker="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
      case "$marker" in
        P|p) parallel="yes" ;;
        P[0-9]*|p[0-9]*) priority="P${marker:1}" ;;
        US[0-9]*|us[0-9]*) story="US${marker:2}" ;;
        *) rest="[$marker] $rest"; break ;;
      esac
    done
    rest="${rest%"${rest##*[![:space:]]}"}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$status" "$story" "$priority" "$parallel" "$issue" "$rest"
  done < "$tasks_file"
}

parse_stories() {
  # parse_stories <spec.md>
  # Prints one line per user story: ID<TAB>PRIORITY<TAB>TITLE
  # Supported headings:
  #   ### User Story 1 - Title (Priority: P1)     (spec-kit template)
  #   ### US1: Title [P1]                         (legacy format)
  local spec_file="$1"
  [[ -f "$spec_file" ]] || return 1

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    local id="" title="" priority=""
    if [[ "$line" =~ ^\#{2,4}[[:space:]]+User[[:space:]]+Story[[:space:]]+([0-9]+)[[:space:]]*(-|–|—|:)[[:space:]]*(.*)$ ]]; then
      id="US${BASH_REMATCH[1]}"
      title="${BASH_REMATCH[3]}"
    elif [[ "$line" =~ ^\#{2,4}[[:space:]]+US([0-9]+)[[:space:]]*(-|–|—|:)[[:space:]]*(.*)$ ]]; then
      id="US${BASH_REMATCH[1]}"
      title="${BASH_REMATCH[3]}"
    else
      continue
    fi

    if [[ "$title" =~ ^(.*)\(Priority:[[:space:]]*(P[0-9]+)\)[[:space:]]*$ ]]; then
      title="${BASH_REMATCH[1]}"
      priority="${BASH_REMATCH[2]}"
    elif [[ "$title" =~ ^(.*)\[(P[0-9]+)\][[:space:]]*$ ]]; then
      title="${BASH_REMATCH[1]}"
      priority="${BASH_REMATCH[2]}"
    fi
    title="${title%"${title##*[![:space:]]}"}"

    printf '%s\t%s\t%s\n' "$id" "$priority" "$title"
  done < "$spec_file"
}

set_task_checkbox() {
  # set_task_checkbox <tasks.md> <task-id> <open|done>
  # Only touches the checkbox of the given task line.
  local tasks_file="$1"
  local id="$2"
  local status="$3"
  local mark=" "
  [[ "$status" == "done" ]] && mark="x"
  sed -i.bak -E "s/^([[:space:]]*[-*][[:space:]]+)\[[ xX]\]([[:space:]]+${id}([[:space:]]|$))/\1[${mark}]\2/" "$tasks_file"
  rm -f "${tasks_file}.bak"
}

annotate_task_issue() {
  # annotate_task_issue <tasks.md> <task-id> <issue-number>
  # Appends "<!-- gitlab:#N -->" to the task line (once).
  local tasks_file="$1"
  local id="$2"
  local issue="$3"
  if grep -qE "^[[:space:]]*[-*][[:space:]]+\[[ xX]\][[:space:]]+${id}([[:space:]]|$).*<!--[[:space:]]*gitlab:#" "$tasks_file"; then
    return 0
  fi
  sed -i.bak -E "s/^([[:space:]]*[-*][[:space:]]+\[[ xX]\][[:space:]]+${id}([[:space:]].*)?)$/\1 <!-- gitlab:#${issue} -->/" "$tasks_file"
  rm -f "${tasks_file}.bak"
}
