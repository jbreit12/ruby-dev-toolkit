# GitHelper

**Author:** Luke Barnett  
**Date:** 08/2/2025  
**Class:** COSC-3353

## Quick Start

### Bash (macOS/Linux/Git Bash/WSL)
```sh
chmod +x scripts/githelper.sh
./scripts/githelper.sh help
```

### PowerShell (Windows)
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
./scripts/GitHelper.ps1 -Action help
```

### VS Code Tasks
- Open Command Palette → "Run Task" → "GitHelper: Menu (Bash)" or "GitHelper: Menu (PowerShell)"

---

## Config Reference (`.githelper.json`)

| Key             | Type      | Default   | Description                                 |
|-----------------|-----------|-----------|---------------------------------------------|
| defaultBase     | string    | dev       | Base branch for new branches/sync           |
| syncStrategy    | string    | rebase    | "rebase" or "merge" for sync/pull           |
| remoteName      | string    | origin    | Remote name                                 |
| enforcePrefix   | bool      | true      | Require branch prefix                       |
| allowedPrefixes | string[]  | ...       | Allowed branch prefixes                     |
| protect         | string[]  | ...       | Protected branches                          |
| confirmOnPrune  | bool      | true      | Confirm before prune                        |
| confirmOnSync   | bool      | false     | Confirm before sync on protected            |
| logLevel        | string    | info      | "silent", "info", "debug"                   |

---

## CLI Reference

### Actions

- `menu` — Interactive menu
- `help` — Show help
- `fetch` — `git fetch --all --prune`
- `list` — List local & remote branches
- `checkout -b <name>` — Checkout or create branch
- `newbranch -b <name>` — New branch from base
- `commitpush -m "<msg>"` — Stage all, commit, push
- `pull` — Pull with strategy
- `sync` — Update current branch on top of base
- `prune` — Prune remotes
- `status` — `git status -sb`
- `upstream` — Set upstream if missing

### Flags

- `--branch/-b <name>`
- `--message/-m "<msg>"`
- `--yes/-y` — Auto-confirm
- `--verbose/-v` — Debug output
- `--dry-run` — Show commands only

### Examples

```sh
./scripts/githelper.sh list
./scripts/githelper.sh checkout -b feature/foo
./scripts/githelper.sh newbranch -b bugfix/bar
./scripts/githelper.sh commitpush -m "fix: update"
./scripts/githelper.sh sync
./scripts/githelper.sh prune --yes
```

---

## Troubleshooting

- **Branches don’t show:** Run `fetch` then `list`
- **Upstream not set:** Use `upstream`
- **Conflicts:** See script output for next steps

---

## FAQ

- **How do I enforce branch prefixes?**  
  Set `enforcePrefix: true` and edit `allowedPrefixes` in `.githelper.json`.

- **How do I change the base branch?**  
  Edit `defaultBase` in `.githelper.json`.

- **How do I resolve conflicts?**  
  Follow the script’s printed instructions after a failed sync/rebase/merge.

---

## Team Conventions

- Use prefixes: `feature/`, `bugfix/`, `hotfix/`
- Protect `main` and `dev` from destructive actions

---

## Tests

### Manual Smoke Test Plan

1. **Missing config file:**  
   - Move `.githelper.json` out of the way, run `help` and `list` — defaults should apply.

2. **New branch with/without allowed prefix:**  
   - Try `newbranch -b feature/test` (should work), `newbranch -b test` (should fail if enforcePrefix).

3. **Checkout remote-only branch:**  
   - Create a branch on remote, delete local, run `checkout -b <name>` — should create tracking.

4. **Commit+push without upstream:**  
   - On new branch, run `commitpush -m "msg"` — should set upstream.

5. **Sync with both strategies:**  
   - Set `syncStrategy` to `rebase` and `merge`, run `sync`.

6. **Prune confirmation and blocking:**  
   - Try `prune` on protected branch, confirm prompt.

7. **Conflicts flow:**  
   - Create a conflict, run `sync`, verify conflict message.

### Optional: Bash Smoke Script

```bash
#!/usr/bin/env bash
# Author: Luke Barnett, Date: 08/2/2025, Class: COSC-3353
# Description: GitHelper smoke test (read-only)

set -e
echo "== help =="
./scripts/githelper.sh help
echo "== list =="
./scripts/githelper.sh list
echo "== status =="
./scripts/githelper.sh status
echo "== dry-run newbranch =="
./scripts/githelper.sh newbranch -b feature/smoke --dry-run
```

---

## Integration Checklist

- Place files at specified paths
- `chmod +x scripts/githelper.sh`
- (Windows, first run) `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- Open VS Code → “Run Task” → GitHelper
- Run smoke tests
