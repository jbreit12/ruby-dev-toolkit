# Author: Luke Barnett, Date: 08/2/2025, Class: COSC-3353
# Description: Cross-platform GitHelper for safe, consistent git workflows (PowerShell version).

param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet("menu","help","fetch","list","checkout","newbranch","commitpush","pull","sync","prune","status","upstream")]
    [string]$Action,
    [string]$Branch,
    [string]$Message,
    [switch]$Yes,
    [switch]$Verbose,
    [switch]$DryRun
)

$APPNAME = "GITHELPER"
$CONFIG_FILE = ".githelper.json"
$EXIT_SUCCESS = 0
$EXIT_INVALID_ARGS = 2
$EXIT_CONFIG_ERROR = 3
$EXIT_GIT_NOT_FOUND = 4
$EXIT_BLOCKED = 5
$EXIT_FAILED = 6

# --- Defaults ---
$config = @{
    defaultBase = "dev"
    syncStrategy = "rebase"
    remoteName = "origin"
    enforcePrefix = $true
    allowedPrefixes = @("feature/","bugfix/","hotfix/")
    protect = @("main","dev")
    confirmOnPrune = $true
    confirmOnSync = $false
    logLevel = "info"
}

function Log {
    param($level, $msg)
    if ($config.logLevel -eq "silent") { return }
    if ($level -eq "debug" -and $config.logLevel -ne "debug") { return }
    Write-Host "[$APPNAME] $level $msg"
}

function Parse-Config {
    if (Test-Path $CONFIG_FILE) {
        try {
            $userConfig = Get-Content $CONFIG_FILE | ConvertFrom-Json
            foreach ($k in $userConfig.PSObject.Properties.Name) {
                $config[$k] = $userConfig.$k
            }
        } catch {
            Log error "Config parse error, using defaults"
        }
    }
}

function Require-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Log error "git not found"
        exit $EXIT_GIT_NOT_FOUND
    }
}

function Find-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) {
        Log error "Not a git repo"
        exit $EXIT_GIT_NOT_FOUND
    }
    Set-Location $root
}

function Is-ProtectedBranch {
    param($branch)
    return $config.protect -contains $branch
}

function Confirm-Action {
    param($msg)
    if ($Yes) { return $true }
    $ans = Read-Host "$msg [y/N]"
    return $ans -match "^[Yy]"
}

function Check-Prefix {
    param($name)
    if (-not $config.enforcePrefix) { return }
    foreach ($p in $config.allowedPrefixes) {
        if ($name.StartsWith($p)) { return }
    }
    Log error "Branch name must start with: $($config.allowedPrefixes -join ', ')"
    exit $EXIT_INVALID_ARGS
}

function Print-Config {
    Write-Host "Effective config:"
    $config.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }
}

function Action-Help {
@"
Usage: GitHelper.ps1 -Action <action> [options]

Actions:
  menu                Interactive menu
  help                Show this help
  fetch               git fetch --all --prune
  list                List local & remote branches
  checkout -Branch <name>  Checkout or create branch
  newbranch -Branch <name> Create new branch from base
  commitpush -Message "<msg>"  Stage all, commit, push
  pull                Pull with strategy
  sync                Update current branch on top of base
  prune               Prune remotes
  status              git status short
  upstream            Set upstream if missing

Flags:
  -Branch <name>
  -Message "<msg>"
  -Yes            Auto-confirm
  -Verbose        Debug output
  -DryRun         Show commands only

Examples:
  ./scripts/GitHelper.ps1 -Action list
  ./scripts/GitHelper.ps1 -Action checkout -Branch feature/foo
  ./scripts/GitHelper.ps1 -Action newbranch -Branch bugfix/bar
  ./scripts/GitHelper.ps1 -Action commitpush -Message "fix: update"
  ./scripts/GitHelper.ps1 -Action sync
  ./scripts/GitHelper.ps1 -Action prune -Yes

"@
    Print-Config
}

function Action-Menu {
    $opts = @("help","fetch","list","checkout","newbranch","commitpush","pull","sync","prune","status","upstream","exit")
    while ($true) {
        $sel = Read-Host "Choose action: $($opts -join ', ')"
        if ($opts -contains $sel) {
            if ($sel -eq "exit") { break }
            &("Action-$($sel.Substring(0,1).ToUpper()+$sel.Substring(1))")
        } else {
            Write-Host "Invalid"
        }
    }
}

function Action-Fetch { git fetch --all --prune }
function Action-List { git branch; git branch -r }
function Action-Checkout {
    if (-not $Branch) { Log error "No branch specified"; exit $EXIT_INVALID_ARGS }
    Check-Prefix $Branch
    if (git show-ref --verify --quiet "refs/heads/$Branch") {
        Log info "Checking out local branch $Branch"
        git checkout $Branch
    } elseif (git ls-remote --exit-code --heads $config.remoteName $Branch 2>$null) {
        Log info "Creating tracking branch $Branch"
        git checkout -b $Branch "$($config.remoteName)/$Branch"
    } else {
        Log info "Creating new branch $Branch from $($config.defaultBase)"
        git checkout -b $Branch "$($config.remoteName)/$($config.defaultBase)"
    }
}
function Action-Newbranch {
    if (-not $Branch) { Log error "No branch specified"; exit $EXIT_INVALID_ARGS }
    Check-Prefix $Branch
    Log info "Creating new branch $Branch from $($config.defaultBase)"
    git checkout -b $Branch "$($config.remoteName)/$($config.defaultBase)"
}
function Action-Commitpush {
    if (-not $Message) { Log error "No commit message"; exit $EXIT_INVALID_ARGS }
    git add -A
    git commit -m "$Message"
    git push --set-upstream $config.remoteName $(git rev-parse --abbrev-ref HEAD)
}
function Action-Pull {
    if ($config.syncStrategy -eq "rebase") {
        git pull --rebase $config.remoteName $(git rev-parse --abbrev-ref HEAD)
    } else {
        git pull $config.remoteName $(git rev-parse --abbrev-ref HEAD)
    }
}
function Action-Sync {
    $branch = git rev-parse --abbrev-ref HEAD
    if (Is-ProtectedBranch $branch -and $config.confirmOnSync -and -not (Confirm-Action "Sync on protected branch. Continue?")) { exit $EXIT_BLOCKED }
    git fetch $config.remoteName $config.defaultBase
    if ($config.syncStrategy -eq "rebase") {
        git rebase "$($config.remoteName)/$($config.defaultBase)"
        if ($LASTEXITCODE -ne 0) {
            Log error "Conflicts detected. Resolve, then:
  git add -A
  git rebase --continue
To abort:
  git rebase --abort"
            exit $EXIT_FAILED
        }
    } else {
        git merge --no-ff "$($config.remoteName)/$($config.defaultBase)"
        if ($LASTEXITCODE -ne 0) {
            Log error "Conflicts detected. Resolve, then:
  git add -A
  git merge --continue
To abort:
  git merge --abort"
            exit $EXIT_FAILED
        }
    }
}
function Action-Prune {
    $branch = git rev-parse --abbrev-ref HEAD
    if (Is-ProtectedBranch $branch -and $config.confirmOnPrune -and -not (Confirm-Action "Prune on protected branch. Continue?")) { exit $EXIT_BLOCKED }
    git fetch --all --prune
    git remote prune $config.remoteName
}
function Action-Status {
    git status -sb
    $branch = git rev-parse --abbrev-ref HEAD
    git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>$null
    if ($LASTEXITCODE -ne 0) { Log info "No upstream set for $branch" }
}
function Action-Upstream {
    $branch = git rev-parse --abbrev-ref HEAD
    git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log info "Setting upstream to $($config.remoteName)/$branch"
        git push --set-upstream $config.remoteName $branch
    }
}

# --- Main ---
Require-Git
Find-RepoRoot
Parse-Config

switch ($Action) {
    "help" { Action-Help }
    "menu" { Action-Menu }
    "fetch" { Action-Fetch }
    "list" { Action-List }
    "checkout" { Action-Checkout }
    "newbranch" { Action-Newbranch }
    "commitpush" { Action-Commitpush }
    "pull" { Action-Pull }
    "sync" { Action-Sync }
    "prune" { Action-Prune }
    "status" { Action-Status }
    "upstream" { Action-Upstream }
    default { Log error "Unknown action: $Action"; Action-Help; exit $EXIT_INVALID_ARGS }
}
