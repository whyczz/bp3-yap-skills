#!/bin/sh
# Point git at the committed hooks in .githooks/.
set -eu
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
echo "hooks installed: core.hooksPath=.githooks"
