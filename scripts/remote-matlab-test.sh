#!/usr/bin/env bash
# Run this repo's MATLAB build tasks on a lab host that has a licensed MATLAB.
# Usage: scripts/remote-matlab-test.sh [buildtool-task ...]   (default: test)
# Env: LGM_HOST (default nemo.local), LGM_MATLAB (default /mnt/onetb/MATLAB/R2025b/bin/matlab),
#      LGM_REMOTE_DIR (default /mnt/onetb/scratch/labgrid-matlab)
set -euo pipefail
HOST=${LGM_HOST:-nemo.local}
MATLAB_BIN=${LGM_MATLAB:-/mnt/onetb/MATLAB/R2025b/bin/matlab}
REMOTE_DIR=${LGM_REMOTE_DIR:-/mnt/onetb/scratch/labgrid-matlab}
TASKS=${*:-test}
here=$(cd "$(dirname "$0")/.." && pwd)
rsync -az --delete --exclude .git --exclude .superpowers --exclude releases --exclude tests/tmp \
  "$here/" "$HOST:$REMOTE_DIR/"
# shellcheck disable=SC2029
ssh "$HOST" "cd '$REMOTE_DIR' && '$MATLAB_BIN' -batch \"buildtool $TASKS\""
