#!/usr/bin/env bash
# private-skills.sh — Manage all private git-backed skills.
#
# Usage:
#   bash private-skills.sh <command> [skill_name]
#
# Commands:
#   list               List all git-backed skills with remote, status, last commit
#   status             Show git status for each git-backed skill
#   push [name]        Commit & push one or all dirty skills
#   pull [name]        Pull latest for one or all skills
#   publish <name>     Init git + create private GitHub repo for a non-git skill

set -euo pipefail

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$(cd "$SKILLS_DIR/.." && pwd)"

CMD="${1:-list}"
SKILL_NAME="${2:-}"

# Collect git-backed skill directories (skip symlinks)
get_skill_dirs() {
  local name_filter="${1:-}"
  for dir in "$SKILLS_DIR"/*/; do
    [ -d "$dir" ] || continue
    [ -L "${dir%/}" ] && continue  # skip symlinks
    [ -d "$dir/.git" ] || continue
    local name
    name="$(basename "$dir")"
    if [ -n "$name_filter" ] && [ "$name" != "$name_filter" ]; then
      continue
    fi
    echo "$dir"
  done
}

# Verify a skill name resolves to a valid directory
require_skill() {
  local name="$1"
  local dir="$SKILLS_DIR/$name"
  if [ ! -d "$dir" ]; then
    echo "Error: skill '$name' not found in $SKILLS_DIR" >&2
    exit 1
  fi
  echo "$dir"
}

cmd_list() {
  local found=0
  for dir in "$SKILLS_DIR"/*/; do
    [ -d "$dir" ] || continue
    [ -L "${dir%/}" ] && continue
    [ -d "$dir/.git" ] || continue
    found=1
    local name
    name="$(basename "$dir")"

    # Remote URL
    local remote
    remote="$(git -C "$dir" remote get-url origin 2>/dev/null || echo "(no remote)")"

    # Clean/dirty
    local status_flag
    if git -C "$dir" diff --quiet 2>/dev/null && git -C "$dir" diff --cached --quiet 2>/dev/null && [ -z "$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null)" ]; then
      status_flag="clean"
    else
      status_flag="dirty"
    fi

    # Last commit
    local last_commit
    last_commit="$(git -C "$dir" log -1 --format='%cd — %s' --date=short 2>/dev/null || echo "(no commits)")"

    printf "%-30s %-6s  %s\n" "$name" "[$status_flag]" "$remote"
    printf "  Last commit: %s\n" "$last_commit"
  done

  if [ "$found" -eq 0 ]; then
    echo "No git-backed skills found in $SKILLS_DIR"
  fi
}

cmd_status() {
  local dirs
  dirs="$(get_skill_dirs "$SKILL_NAME")"
  if [ -z "$dirs" ]; then
    if [ -n "$SKILL_NAME" ]; then
      echo "Skill '$SKILL_NAME' is not a git-backed skill."
    else
      echo "No git-backed skills found."
    fi
    return
  fi

  while IFS= read -r dir; do
    local name
    name="$(basename "$dir")"
    echo "=== $name ==="

    # Ahead/behind
    local upstream
    upstream="$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
    if [ -n "$upstream" ]; then
      local ahead behind
      ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
      behind="$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)"
      echo "  Branch: $(git -C "$dir" branch --show-current) | ahead $ahead, behind $behind"
    else
      echo "  Branch: $(git -C "$dir" branch --show-current 2>/dev/null || echo '(detached)') | no upstream"
    fi

    # Git status
    local st
    st="$(git -C "$dir" status --short 2>/dev/null)"
    if [ -z "$st" ]; then
      echo "  Working tree clean"
    else
      echo "$st" | sed 's/^/  /'
    fi
    echo ""
  done <<< "$dirs"
}

cmd_push() {
  local dirs
  dirs="$(get_skill_dirs "$SKILL_NAME")"
  if [ -z "$dirs" ]; then
    if [ -n "$SKILL_NAME" ]; then
      echo "Skill '$SKILL_NAME' is not a git-backed skill."
    else
      echo "No git-backed skills found."
    fi
    return
  fi

  local pushed=0
  while IFS= read -r dir; do
    local name
    name="$(basename "$dir")"

    # Check if dirty (including untracked files)
    if git -C "$dir" diff --quiet 2>/dev/null && git -C "$dir" diff --cached --quiet 2>/dev/null && [ -z "$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null)" ]; then
      echo "Skip: $name (no changes)"
      continue
    fi

    echo "Pushing: $name ..."
    git -C "$dir" add -A
    git -C "$dir" commit -m "Update $name" 2>&1 | sed 's/^/  /'
    git -C "$dir" push 2>&1 | sed 's/^/  /'
    pushed=$((pushed + 1))
  done <<< "$dirs"

  if [ "$pushed" -eq 0 ]; then
    echo "All skills are clean — nothing to push."
  else
    echo ""
    echo "Done. Pushed $pushed skill(s)."
  fi
}

cmd_pull() {
  local dirs
  dirs="$(get_skill_dirs "$SKILL_NAME")"
  if [ -z "$dirs" ]; then
    if [ -n "$SKILL_NAME" ]; then
      echo "Skill '$SKILL_NAME' is not a git-backed skill."
    else
      echo "No git-backed skills found."
    fi
    return
  fi

  while IFS= read -r dir; do
    local name
    name="$(basename "$dir")"
    echo "Pulling: $name ..."
    git -C "$dir" pull --rebase 2>&1 | sed 's/^/  /'
  done <<< "$dirs"

  echo ""
  echo "Done. All skills up to date."
}

cmd_publish() {
  if [ -z "$SKILL_NAME" ]; then
    echo "Error: publish requires a skill name." >&2
    echo "Usage: private-skills.sh publish <skill_name>" >&2
    exit 1
  fi

  local dir
  dir="$(require_skill "$SKILL_NAME")"

  if [ -d "$dir/.git" ]; then
    echo "Error: '$SKILL_NAME' is already a git repo. Use 'push' instead." >&2
    exit 1
  fi

  if [ ! -f "$dir/SKILL.md" ]; then
    echo "Error: '$SKILL_NAME' has no SKILL.md — is it a valid skill?" >&2
    exit 1
  fi

  echo "Publishing: $SKILL_NAME ..."
  git -C "$dir" init 2>&1 | sed 's/^/  /'
  git -C "$dir" add -A
  git -C "$dir" commit -m "Initial commit for $SKILL_NAME" 2>&1 | sed 's/^/  /'
  gh repo create "EFFYLYX/$SKILL_NAME" --private --source="$dir" --push 2>&1 | sed 's/^/  /'

  echo ""
  echo "Done. $SKILL_NAME published to github.com/EFFYLYX/$SKILL_NAME (private)."
}

case "$CMD" in
  list)    cmd_list ;;
  status)  cmd_status ;;
  push)    cmd_push ;;
  pull)    cmd_pull ;;
  publish) cmd_publish ;;
  *)
    echo "Unknown command: $CMD" >&2
    echo "Usage: private-skills.sh <list|status|push|pull|publish> [skill_name]" >&2
    exit 1
    ;;
esac
