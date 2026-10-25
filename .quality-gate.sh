#!/usr/bin/env bash
# Project checks for quality-gate: $1 is "quick" or "full".
set -euo pipefail

mise exec -- make lint
if [[ "${1:-full}" == "full" ]]; then
  mise exec -- make test
fi
