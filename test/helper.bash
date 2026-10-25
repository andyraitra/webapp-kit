# Shared setup for the bats suites.
#
# Every test runs with a throwaway $HOME and a PATH that only contains the
# system tools the scripts are allowed to depend on, plus stubs for curl,
# the browsers and update-desktop-database. Nothing touches the network or
# the real desktop.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export INSTALL="$REPO_ROOT/bin/webapp-install"
export REMOVE="$REPO_ROOT/bin/webapp-remove"

common_setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset XDG_DATA_HOME WEBAPP_BROWSER

  export APPS="$HOME/.local/share/applications"
  export ICONS="$HOME/.local/share/icons/webapps"

  STUBS="$BATS_TEST_TMPDIR/stubs"
  SYSBIN="$BATS_TEST_TMPDIR/sysbin"
  FIXTURES="$BATS_TEST_TMPDIR/fixtures"
  mkdir -p "$STUBS" "$SYSBIN" "$FIXTURES"

  # Tools available to the scripts under test (ls and cmp are for assertions).
  local tool
  for tool in bash env cat cp mv rm mkdir mktemp chmod tr sed grep head cut sort \
    basename dirname file printf wc tail ls cmp; do
    if command -v "$tool" >/dev/null 2>&1; then
      ln -sf "$(command -v "$tool")" "$SYSBIN/$tool"
    fi
  done

  export CURL_ROUTES="$BATS_TEST_TMPDIR/curl-routes"
  export CURL_LOG="$BATS_TEST_TMPDIR/curl-log"
  : >"$CURL_ROUTES"
  : >"$CURL_LOG"
  write_curl_stub

  printf '#!/bin/sh\nexit 0\n' >"$STUBS/update-desktop-database"
  chmod +x "$STUBS/update-desktop-database"

  PYTHON="$(command -v python3)"
  export PATH="$STUBS:$SYSBIN"
  add_browser brave-browser
}

add_browser() {
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}

remove_browser() {
  rm -f "$STUBS/$1"
}

# route <url> <fixture-file> [effective-url]
# Serves the fixture for that exact URL. Unrouted URLs answer 404.
# A fixture of the form "redirect:<target>" answers a 302 to <target>.
route() {
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-$1}" >>"$CURL_ROUTES"
}

# Minimal curl replacement: honours -f, -o, -w ('%{url_effective}' and
# '%{redirect_url}'; redirects are never followed) and logs every invocation
# (one line per call) so tests can assert on the flags.
write_curl_stub() {
  cat >"$STUBS/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CURL_LOG"
fail=0 out="" url="" wfmt=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    -w) wfmt="$2"; shift ;;
    -A | --max-time | --max-filesize | --proto | --proto-redir | --max-redirs) shift ;;
    -*) case "$1" in -*f*) [[ "$1" != --* ]] && fail=1 ;; esac ;;
    *) url="$1" ;;
  esac
  shift
done
line=$(awk -F'\t' -v u="$url" '$1 == u { print; exit }' "$CURL_ROUTES" 2>/dev/null || true)
if [ -z "$line" ]; then
  [ "$fail" = 1 ] && exit 22
  [ -n "$out" ] && printf 'not found' >"$out"
  exit 0
fi
fixture=$(printf '%s' "$line" | cut -f2)
effective=$(printf '%s' "$line" | cut -f3)
redirect=""
if [[ "$fixture" == redirect:* ]]; then
  redirect="${fixture#redirect:}"
  [ -n "$out" ] && : >"$out"
elif [ -n "$out" ]; then
  cat "$fixture" >"$out"
else
  cat "$fixture"
fi
wfmt="${wfmt//%\{url_effective\}/$effective}"
[ -n "$wfmt" ] && printf '%s' "${wfmt//%\{redirect_url\}/$redirect}"
exit 0
EOF
  chmod +x "$STUBS/curl"
  ln -sf "$(command -v awk)" "$SYSBIN/awk"
}

# make_png <width> <height> <path>: write a valid RGBA PNG of that size.
make_png() {
  "$PYTHON" - "$1" "$2" "$3" <<'EOF'
import struct, sys, zlib
w, h, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
raw = b"".join(b"\x00" + b"\xe8\x71\x0a\xff" * w for _ in range(h))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open(path, "wb").write(png)
EOF
}

make_svg() {
  cat >"$1" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" fill="#e8710a"/></svg>
EOF
}

# html_page <path> <head-html>
html_page() {
  printf '<!doctype html><html><head><title>t</title>%s</head><body></body></html>\n' "$2" >"$1"
}

export DASHBOARD="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png"
export GOOGLE="https://www.google.com/s2/favicons"

desktop_file() {
  printf '%s/webapp-%s.desktop' "$APPS" "$1"
}

desktop_value() {
  grep -m1 "^$2=" "$(desktop_file "$1")" | cut -d= -f2-
}

# make_gif <width> <height> <path>
make_gif() {
  "$PYTHON" - "$1" "$2" "$3" <<'PY'
import struct, sys
w, h, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
data = b"GIF89a" + struct.pack("<HH", w, h) + b"\x80\x00\x00" + b"\x00\x00\x00\xff\xff\xff"
data += b"\x2c" + struct.pack("<HHHH", 0, 0, w, h) + b"\x00" + b"\x02\x02\x44\x01\x00" + b"\x3b"
open(path, "wb").write(data)
PY
}

# make_ico_png <size> <path>: ICO file embedding a PNG of that size.
make_ico_png() {
  local png="$BATS_TEST_TMPDIR/inner.png"
  make_png "$1" "$1" "$png"
  "$PYTHON" - "$1" "$png" "$2" <<'PY'
import struct, sys
s, png, path = int(sys.argv[1]), open(sys.argv[2], "rb").read(), sys.argv[3]
b = 0 if s >= 256 else s
data = struct.pack("<HHH", 0, 1, 1) + struct.pack("<BBBBHHII", b, b, 0, 0, 1, 32, len(png), 22) + png
open(path, "wb").write(data)
PY
}
