#!/usr/bin/env ruby
# Author: Luke Barnett, Date: 08/2/2025, Class: COSC-3353
# Description: Cross-platform GitHelper for safe, consistent git workflows (Ruby version).

require 'json'
require 'open3'

APPNAME = "GITHELPER"
CONFIG_FILE = ".githelper.json"
EXIT_SUCCESS = 0
EXIT_INVALID_ARGS = 2
EXIT_CONFIG_ERROR = 3
EXIT_GIT_NOT_FOUND = 4
EXIT_BLOCKED = 5
EXIT_FAILED = 6

# --- Defaults ---
CONFIG = {
  "defaultBase" => "dev",
  "syncStrategy" => "rebase",
  "remoteName" => "origin",
  "enforcePrefix" => true,
  "allowedPrefixes" => ["feature/", "bugfix/", "hotfix/"],
  "protect" => ["main", "dev"],
  "confirmOnPrune" => true,
  "confirmOnSync" => false,
  "logLevel" => "info"
}

# --- Logging ---
def log(level, *msg)
  return if CONFIG["logLevel"] == "silent"
  return if level == "debug" && CONFIG["logLevel"] != "debug"
  puts "[#{APPNAME}] #{level} #{msg.join(' ')}"
end

# --- Config ---
def parse_config
  if File.exist?(CONFIG_FILE)
    begin
      user_config = JSON.parse(File.read(CONFIG_FILE))
      user_config.each { |k, v| CONFIG[k] = v }
    rescue
      log("error", "Config parse error, using defaults")
    end
  end
end

# --- Helpers ---
def require_git
  system('git --version >nul 2>&1') || (log("error", "git not found"); exit(EXIT_GIT_NOT_FOUND))
end

def find_repo_root
  root = `git rev-parse --show-toplevel`.strip
  if root.empty?
    log("error", "Not a git repo"); exit(EXIT_GIT_NOT_FOUND)
  end
  Dir.chdir(root)
end

def is_protected_branch(branch)
  CONFIG["protect"].include?(branch)
end

def confirm(msg, yes=false)
  return true if yes
  print "#{msg} [y/N]: "
  ans = $stdin.gets.strip
  ans =~ /^[Yy]$/
end

def check_prefix(name)
  return true unless CONFIG["enforcePrefix"]
  CONFIG["allowedPrefixes"].any? { |p| name.start_with?(p) } || (log("error", "Branch name must start with one of: #{CONFIG["allowedPrefixes"].join(' ')}"); exit(EXIT_INVALID_ARGS))
end

def print_config
  puts "Effective config:"
  CONFIG.each { |k, v| puts "  #{k}: #{v}" }
end

# --- Actions ---
def action_help
  puts <<~EOF
    Usage: githelper.rb <action> [options]

    Actions:
      menu                Interactive menu
      help                Show this help
      fetch               git fetch --all --prune
      list                List local & remote branches
      checkout -b <name>  Checkout or create branch
      newbranch -b <name> Create new branch from base
      commitpush -m "<msg>"  Stage all, commit, push (runs pre-commit checks)
      pull                Pull with strategy (auto-stash)
      sync                Update current branch on top of base (auto-stash)
      prune               Prune remotes
      status              git status short
      upstream            Set upstream if missing
      cleanbranches       Interactive cleanup of stale local branches

    Flags:
      --branch/-b <name>
      --message/-m "<msg>"
      --yes/-y            Auto-confirm
      --verbose/-v        Debug output
      --dry-run           Show commands only

    Examples:
      ruby scripts/githelper.rb list
      ruby scripts/githelper.rb checkout -b feature/foo
      ruby scripts/githelper.rb newbranch -b bugfix/bar
      ruby scripts/githelper.rb commitpush -m "fix: update"
      ruby scripts/githelper.rb sync
      ruby scripts/githelper.rb prune --yes
  EOF
  print_config
end

def action_menu
  opts = %w[help fetch list checkout newbranch commitpush pull sync prune status upstream cleanbranches exit]
  loop do
    print "Choose action: #{opts.join(', ')}: "
    sel = $stdin.gets.strip
    if opts.include?(sel)
      break if sel == "exit"
      send("action_#{sel}")
    else
      puts "Invalid"
    end
  end
end

def action_fetch
  log("info", "Fetching all remotes...")
  system('git fetch --all --prune')
end

def action_list
  log("info", "Local branches:")
  system('git branch')
  log("info", "Remote branches:")
  system('git branch -r')
end

def action_checkout(branch=nil, dryrun=false)
  branch ||= ARGV[1]
  dryrun ||= ARGV.include?('--dry-run')
  if branch.nil? || branch.empty?
    log("error", "No branch specified"); exit(EXIT_INVALID_ARGS)
  end
  check_prefix(branch)
  if system("git show-ref --verify --quiet refs/heads/#{branch}")
    log("info", "Checking out local branch #{branch}")
    system("git checkout #{branch}")
  elsif system("git ls-remote --exit-code --heads #{CONFIG["remoteName"]} #{branch} >nul 2>&1")
    log("info", "Creating tracking branch #{branch}")
    system("git checkout -b #{branch} #{CONFIG["remoteName"]}/#{branch}")
  else
    log("info", "Creating new branch #{branch} from #{CONFIG["defaultBase"]}")
    system("git checkout -b #{branch} #{CONFIG["remoteName"]}/#{CONFIG["defaultBase"]}")
  end
end

def action_newbranch(branch=nil, dryrun=false)
  branch ||= ARGV[1]
  dryrun ||= ARGV.include?('--dry-run')
  if branch.nil? || branch.empty?
    log("error", "No branch specified"); exit(EXIT_INVALID_ARGS)
  end
  check_prefix(branch)
  log("info", "Creating new branch #{branch} from #{CONFIG["defaultBase"]}")
  system("git checkout -b #{branch} #{CONFIG["remoteName"]}/#{CONFIG["defaultBase"]}")
end

def action_commitpush(msg=nil, dryrun=false)
  msg ||= ARGV[1]
  dryrun ||= ARGV.include?('--dry-run')
  if msg.nil? || msg.empty?
    log("error", "No commit message"); exit(EXIT_INVALID_ARGS)
  end
  unless pre_commit_checks
    log("error", "Pre-commit checks failed. Commit aborted."); exit(EXIT_FAILED)
  end
  system('git add -A')
  system("git commit -m \"#{msg}\"") || log("info", "Nothing to commit")
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  system("git push --set-upstream #{CONFIG["remoteName"]} #{branch}")
end

def action_pull
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  stash_needed = !`git status --porcelain`.strip.empty?
  system('git stash') if stash_needed
  if CONFIG["syncStrategy"] == "rebase"
    system("git pull --rebase #{CONFIG["remoteName"]} #{branch}")
  else
    system("git pull #{CONFIG["remoteName"]} #{branch}")
  end
  system('git stash pop') if stash_needed
end

def action_sync(yes=false)
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  if is_protected_branch(branch) && CONFIG["confirmOnSync"] && !confirm("Sync on protected branch. Continue?", yes)
    exit(EXIT_BLOCKED)
  end
  stash_needed = !`git status --porcelain`.strip.empty?
  system('git stash') if stash_needed
  system("git fetch #{CONFIG["remoteName"]} #{CONFIG["defaultBase"]}")
  if CONFIG["syncStrategy"] == "rebase"
    unless system("git rebase #{CONFIG["remoteName"]}/#{CONFIG["defaultBase"]}")
      log("error", "Conflicts detected. Resolve, then:\n  git add -A\n  git rebase --continue\nTo abort:\n  git rebase --abort")
      exit(EXIT_FAILED)
    end
  else
    unless system("git merge --no-ff #{CONFIG["remoteName"]}/#{CONFIG["defaultBase"]}")
      log("error", "Conflicts detected. Resolve, then:\n  git add -A\n  git merge --continue\nTo abort:\n  git merge --abort")
      exit(EXIT_FAILED)
    end
  end
  system('git stash pop') if stash_needed
end

def action_prune(yes=false)
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  if is_protected_branch(branch) && CONFIG["confirmOnPrune"] && !confirm("Prune on protected branch. Continue?", yes)
    exit(EXIT_BLOCKED)
  end
  system('git fetch --all --prune')
  system("git remote prune #{CONFIG["remoteName"]}")
end

def action_status
  system('git status -sb')
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  unless system('git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1')
    log("info", "No upstream set for #{branch}")
  end
end

def action_upstream
  branch = `git rev-parse --abbrev-ref HEAD`.strip
  unless system('git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1')
    log("info", "Setting upstream to #{CONFIG["remoteName"]}/#{branch}")
    system("git push --set-upstream #{CONFIG["remoteName"]} #{branch}")
  end
end

# --- Main ---
def main
  require_git
  find_repo_root
  parse_config
  if ARGV.empty?
    action_help
    exit(EXIT_INVALID_ARGS)
  end
  action = ARGV[0]
  case action
  when "help" then action_help
  when "menu" then action_menu
  when "fetch" then action_fetch
  when "list" then action_list
  when "checkout" then action_checkout(ARGV[2])
  when "newbranch" then action_newbranch(ARGV[2])
  when "commitpush" then action_commitpush(ARGV[2])
  when "pull" then action_pull
  when "sync" then action_sync(ARGV.include?("--yes") || ARGV.include?("-y"))
  when "prune" then action_prune(ARGV.include?("--yes") || ARGV.include?("-y"))
  when "status" then action_status
  when "upstream" then action_upstream
  when "cleanbranches" then action_cleanbranches
  else
    log("error", "Unknown action: #{action}"); action_help; exit(EXIT_INVALID_ARGS)
  end
end

# --- New Features ---
def action_cleanbranches
  local_branches = `git branch --format="%(refname:short)"`.lines.map(&:strip)
  remote_branches = `git branch -r --format="%(refname:short)"`.lines.map { |b| b.sub(/^[^\/]+\//, '').strip }
  stale = local_branches - remote_branches - ["main", "dev"]
  if stale.empty?
    puts "No stale branches to clean."
    return
  end
  puts "Stale local branches:"
  stale.each_with_index { |b, i| puts "  [#{i+1}] #{b}" }
  print "Delete these branches? [y/N]: "
  ans = $stdin.gets.strip
  if ans =~ /^[Yy]$/
    stale.each { |b| system("git branch -D #{b}") }
    puts "Deleted stale branches."
  else
    puts "No branches deleted."
  end
end

def pre_commit_checks
  # Example: run tests and lint (customize as needed)
  tests = system('scripts/smoke.sh') if File.exist?('scripts/smoke.sh')
  lint = true # Add lint command if available
  tests && lint
end

main if __FILE__ == $0
