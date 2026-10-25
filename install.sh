#!/usr/bin/env bash
# Install webapp-install and webapp-remove into $PREFIX/bin (default ~/.local).
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"
DEST="$PREFIX/bin"

for dep in curl file; do
  command -v "$dep" >/dev/null 2>&1 || printf 'warning: %s is required at runtime but was not found\n' "$dep" >&2
done

mkdir -p -- "$DEST"
for tool in webapp-install webapp-remove; do
  install -m 755 -- "$SRC/$tool" "$DEST/$tool"
  printf 'Installed %s\n' "$DEST/$tool"
done

case ":$PATH:" in
  *":$DEST:"*) ;;
  *)
    printf '\nNote: %s is not in your PATH. Add this to your shell profile:\n' "$DEST"
    printf '  export PATH="%s:%s"\n' "$DEST" "\$PATH"
    ;;
esac
