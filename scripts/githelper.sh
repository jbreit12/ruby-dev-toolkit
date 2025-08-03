#!/usr/bin/env bash
# Author: Luke Barnett, Date: 08/2/2025, Class: COSC-3353
# Description: Cross-platform GitHelper for safe, consistent git workflows (Bash version).

set -euo pipefail

# --- Constants ---
APPNAME="GITHELPER"
CONFIG_FILE=".githelper.json"
REPO_ROOT=""
LOG_LEVEL="info"
EXIT_SUCCESS=0
EXIT_INVALID_ARGS=2
EXIT_CONFIG_ERROR=3
EXIT_GIT_NOT_FOUND=4
EXIT_BLOCKED=5
EXIT_FAILED=6

# --- Defaults ---
defaultBase="dev"
syncStrategy="rebase"
remoteName="origin"
enforcePrefix="true"
allowedPrefixes=("feature/" "bugfix/" "hotfix/")
protect=("main" "dev")
confirmOnPrune="true"
confirmOnSync="false"
logLevel="info"

# --- Logging ---
log() {
  local level="$1"; shift
  [[ "$level" == "silent" ]] && return
  [[ "$level" == "debug" && "$LOG_LEVEL" != "debug" ]] && return
  echo "[$APPNAME] $level $*"
}

# --- Config ---
parse_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
      defaultBase=$(jq -r '.defaultBase // "dev"' "$CONFIG_FILE")
      syncStrategy=$(jq -r '.syncStrategy // "rebase"' "$CONFIG_FILE")
      remoteName=$(jq -r '.remoteName // "origin"' "$CONFIG_FILE")
      enforcePrefix=$(jq -r '.enforcePrefix // true' "$CONFIG_FILE")
      allowedPrefixes=($(jq -r '.allowedPrefixes[]?' "$CONFIG_FILE"))
      protect=($(jq -r '.protect[]?' "$CONFIG_FILE"))
      confirmOnPrune=$(jq -r '.confirmOnPrune // true' "$CONFIG_FILE")
      confirmOnSync=$(jq -r '.confirmOnSync // false' "$CONFIG_FILE")
      logLevel=$(jq -r '.logLevel // "info"' "$CONFIG_FILE")
    else
      # Fallback: grep/sed/awk
      defaultBase=$(grep -o '"defaultBase": *"[^"]*"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "dev")
      syncStrategy=$(grep -o '"syncStrategy": *"[^"]*"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "rebase")
      remoteName=$(grep -o '"remoteName": *"[^"]*"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "origin")
      enforcePrefix=$(grep -o '"enforcePrefix": *[^,]*' "$CONFIG_FILE" | grep -q true && echo "true" || echo "false")
      allowedPrefixes=("feature/" "bugfix/" "hotfix/")
      protect=("main" "dev")
      confirmOnPrune=$(grep -o '"confirmOnPrune": *[^,]*' "$CONFIG_FILE" | grep -q true && echo "true" || echo "false")
      confirmOnSync=$(grep -o '"confirmOnSync": *[^,]*' "$CONFIG_FILE" | grep -q true && echo "true" || echo "false")
      logLevel=$(grep -o '"logLevel": *"[^"]*"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "info")
    fi
  fi
  LOG_LEVEL="$logLevel"
}

# --- Helpers ---
require_git() {
  command -v git >/dev/null 2>&1 || { log error "git not found"; exit $EXIT_GIT_NOT_FOUND; }
}

find_repo_root() {
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { log error "Not a git repo"; exit $EXIT_GIT_NOT_FOUND; }
  cd "$REPO_ROOT"
}

is_protected_branch() {
  local branch="$1"
  for p in "${protect[@]}"; do [[ "$branch" == "$p" ]] && return 0; done
  return 1
}

confirm() {
  local msg="$1"
  [[ "${2:-}" == "--yes" ]] && return 0
  read -rp "$msg [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

check_prefix() {
  local name="$1"
  [[ "$enforcePrefix" != "true" ]] && return 0
  for p in "${allowedPrefixes[@]}"; do [[ "$name" == "$p"* ]] && return 0; done
  log error "Branch name must start with one of: ${allowedPrefixes[*]}"
  exit $EXIT_INVALID_ARGS
}

print_config() {
  echo "Effective config:"
  echo "  defaultBase: $defaultBase"
  echo "  syncStrategy: $syncStrategy"
  echo "  remoteName: $remoteName"
  echo "  enforcePrefix: $enforcePrefix"
  echo "  allowedPrefixes: ${allowedPrefixes[*]}"
  echo "  protect: ${protect[*]}"
  echo "  confirmOnPrune: $confirmOnPrune"
  echo "  confirmOnSync: $confirmOnSync"
  echo "  logLevel: $logLevel"
}

# --- Actions ---
action_help() {
  cat <<EOF
Usage: githelper.sh <action> [options]

Actions:
  menu                Interactive menu
  help                Show this help
  fetch               git fetch --all --prune
  list                List local & remote branches
  checkout -b <name>  Checkout or create branch
  newbranch -b <name> Create new branch from base
  commitpush -m "<msg>"  Stage all, commit, push
  pull                Pull with strategy
  sync                Update current branch on top of base
  prune               Prune remotes
  status              git status short
  upstream            Set upstream if missing

Flags:
  --branch/-b <name>
  --message/-m "<msg>"
  --yes/-y            Auto-confirm
  --verbose/-v        Debug output
  --dry-run           Show commands only

Examples:
  ./scripts/githelper.sh list
  ./scripts/githelper.sh checkout -b feature/foo
  ./scripts/githelper.sh newbranch -b bugfix/bar
  ./scripts/githelper.sh commitpush -m "fix: update"
  ./scripts/githelper.sh sync
  ./scripts/githelper.sh prune --yes

EOF
  print_config
}

action_menu() {
  select opt in "help" "fetch" "list" "checkout" "newbranch" "commitpush" "pull" "sync" "prune" "status" "upstream" "exit"; do
    case $opt in
      help) action_help ;;
      fetch) action_fetch ;;
      list) action_list ;;
      checkout) action_checkout "$@" ;;
      newbranch) action_newbranch "$@" ;;
      commitpush) action_commitpush "$@" ;;
      pull) action_pull ;;
      sync) action_sync "$@" ;;
      prune) action_prune "$@" ;;
      status) action_status ;;
      upstream) action_upstream ;;
      exit) break ;;
      *) echo "Invalid";;
    esac
  done
}

action_fetch() {
  log info "Fetching all remotes..."
  git fetch --all --prune
}

action_list() {
  log info "Local branches:"
  git branch
  log info "Remote branches:"
  git branch -r
}

action_checkout() {
  local branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--branch) branch="$2"; shift 2 ;;
      --dry-run) DRYRUN=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$branch" ]] && { log error "No branch specified"; exit $EXIT_INVALID_ARGS; }
  check_prefix "$branch"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    log info "Checking out local branch $branch"
    git checkout "$branch"
  elif git ls-remote --exit-code --heads "$remoteName" "$branch" >/dev/null 2>&1; then
    log info "Creating tracking branch $branch"
    git checkout -b "$branch" "$remoteName/$branch"
  else
    log info "Creating new branch $branch from $defaultBase"
    git checkout -b "$branch" "$remoteName/$defaultBase"
  fi
}

action_newbranch() {
  local branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--branch) branch="$2"; shift 2 ;;
      --dry-run) DRYRUN=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$branch" ]] && { log error "No branch specified"; exit $EXIT_INVALID_ARGS; }
  check_prefix "$branch"
  log info "Creating new branch $branch from $defaultBase"
  git checkout -b "$branch" "$remoteName/$defaultBase"
}

action_commitpush() {
  local msg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--message) msg="$2"; shift 2 ;;
      --dry-run) DRYRUN=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$msg" ]] && { log error "No commit message"; exit $EXIT_INVALID_ARGS; }
  git add -A
  git commit -m "$msg" || log info "Nothing to commit"
  git push --set-upstream "$remoteName" "$(git rev-parse --abbrev-ref HEAD)"
}

action_pull() {
  if [[ "$syncStrategy" == "rebase" ]]; then
    git pull --rebase "$remoteName" "$(git rev-parse --abbrev-ref HEAD)"
  else
    git pull "$remoteName" "$(git rev-parse --abbrev-ref HEAD)"
  fi
}

action_sync() {
  local branch="$(git rev-parse --abbrev-ref HEAD)"
  is_protected_branch "$branch" && [[ "$confirmOnSync" == "true" ]] && ! confirm "Sync on protected branch. Continue?" && exit $EXIT_BLOCKED
  git fetch "$remoteName" "$defaultBase"
  if [[ "$syncStrategy" == "rebase" ]]; then
    git rebase "$remoteName/$defaultBase" || {
      log error "Conflicts detected. Resolve, then:
  git add -A
  git rebase --continue
To abort:
  git rebase --abort"
      exit $EXIT_FAILED
    }
  else
    git merge --no-ff "$remoteName/$defaultBase" || {
      log error "Conflicts detected. Resolve, then:
  git add -A
  git merge --continue
To abort:
  git merge --abort"
      exit $EXIT_FAILED
    }
  fi
}

action_prune() {
  local branch="$(git rev-parse --abbrev-ref HEAD)"
  is_protected_branch "$branch" && [[ "$confirmOnPrune" == "true" ]] && ! confirm "Prune on protected branch. Continue?" && exit $EXIT_BLOCKED
  git fetch --all --prune
  git remote prune "$remoteName"
}

action_status() {
  git status -sb
  local branch="$(git rev-parse --abbrev-ref HEAD)"
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || log info "No upstream set for $branch"
}

action_upstream() {
  local branch="$(git rev-parse --abbrev-ref HEAD)"
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || {
    log info "Setting upstream to $remoteName/$branch"
    git push --set-upstream "$remoteName" "$branch"
  }
}

# --- Main ---
main() {
  require_git
  find_repo_root
  parse_config

  [[ $# -eq 0 ]] && { action_help; exit $EXIT_INVALID_ARGS; }
  case "$1" in
    help) action_help ;;
    menu) action_menu ;;
    fetch) action_fetch ;;
    list) action_list ;;
    checkout) shift; action_checkout "$@" ;;
    newbranch) shift; action_newbranch "$@" ;;
    commitpush) shift; action_commitpush "$@" ;;
    pull) action_pull ;;
    sync) action_sync "$@" ;;
    prune) action_prune "$@" ;;
    status) action_status ;;
    upstream) action_upstream ;;
    *) log error "Unknown action: $1"; action_help; exit $EXIT_INVALID_ARGS ;;
  esac
}

main "$@"
