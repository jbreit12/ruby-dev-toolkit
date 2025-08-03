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
