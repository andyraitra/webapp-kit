#!/usr/bin/env bash
# Remove webapp-install and webapp-remove from $PREFIX/bin (default ~/.local).
# Installed web apps are kept; remove them first with `webapp-remove <Name>`.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

for tool in webapp-install webapp-remove; do
  if [[ -e "$PREFIX/bin/$tool" ]]; then
    rm -f -- "$PREFIX/bin/$tool"
    printf 'Removed %s\n' "$PREFIX/bin/$tool"
  fi
done
