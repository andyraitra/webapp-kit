#!/usr/bin/env bats

load helper

setup() {
  common_setup
}

@test "the largest declared icon size wins" {
  make_png 96 96 "$FIXTURES/small.png"
  make_png 192 192 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="96x96" href="/s.png"><link rel="icon" sizes="192x192" href="/b.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/s.png" "$FIXTURES/small.png"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  "$INSTALL" "Sized" https://a.example/
  cmp -s "$ICONS/sized.png" "$FIXTURES/big.png"
}

@test "declared apple-touch-icon at a non-conventional path is used" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" href="/favicon.ico"><link rel="apple-touch-icon" sizes="180x180" href="/static/touch-180.png" />'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/static/touch-180.png" "$FIXTURES/touch.png"
  "$INSTALL" "Touch" https://a.example/
  cmp -s "$ICONS/touch.png" "$FIXTURES/touch.png"
}

@test "apple-touch-icon beats a larger rel=icon" {
  make_png 180 180 "$FIXTURES/touch.png"
  make_png 512 512 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="512x512" href="/b.png"><link rel="apple-touch-icon" href="/t.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  route "https://a.example/t.png" "$FIXTURES/touch.png"
  "$INSTALL" "Order" https://a.example/
  cmp -s "$ICONS/order.png" "$FIXTURES/touch.png"
}

@test "apple-touch-icon-precomposed is ranked as apple-touch-icon" {
  make_png 152 152 "$FIXTURES/touch.png"
  make_png 512 512 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="512x512" href="/b.png"><link rel="apple-touch-icon-precomposed" href="/p.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  route "https://a.example/p.png" "$FIXTURES/touch.png"
  "$INSTALL" "Pre" https://a.example/
  cmp -s "$ICONS/pre.png" "$FIXTURES/touch.png"
}

@test "sizes=any icon beats a sized PNG" {
  make_svg "$FIXTURES/any.svg"
  make_png 192 192 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="192x192" href="/b.png"><link rel="icon" sizes="any" href="/any-icon">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  route "https://a.example/any-icon" "$FIXTURES/any.svg"
  "$INSTALL" "Any" https://a.example/
  [ -f "$ICONS/any.svg" ]
}

@test "at most 6 declared candidates are tried, then the conventional fallback" {
  local head="" i
  for i in 1 2 3 4 5 6 7 8; do head+="<link rel=\"icon\" href=\"/i$i.png\">"; done
  html_page "$FIXTURES/page.html" "$head"
  route "https://a.example/" "$FIXTURES/page.html"
  run "$INSTALL" "Cap" https://a.example/
  [ "$status" -eq 0 ]
  [ "$(grep -c '^-fsS.*https://a.example/i[0-9].png$' "$CURL_LOG")" -eq 6 ]
  run ! grep -q 'i7.png' "$CURL_LOG"
  grep -q 'a.example/apple-touch-icon.png' "$CURL_LOG"
}

@test "redirect: conventional apple-touch-icon uses the final origin" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" ''
  route "http://a.example/" "$FIXTURES/page.html" "https://www.a.example/home"
  route "https://www.a.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  "$INSTALL" "Redir" http://a.example/
  cmp -s "$ICONS/redir.png" "$FIXTURES/touch.png"
}

@test "http site: protocol-relative and conventional URLs keep http" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="//cdn.example/t.png">'
  route "http://plain.example/" "$FIXTURES/page.html"
  route "http://cdn.example/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Plain" http://plain.example/
  cmp -s "$ICONS/plain.png" "$FIXTURES/a.png"
  [ "$(desktop_value plain Exec)" = 'brave-browser --new-window --ozone-platform-hint=auto "--app=http://plain.example/"' ]
}

@test "multi-line link tag with uppercase attributes and href first" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" $'<LINK\n  HREF="/Up.png"\n  REL="Apple-Touch-Icon"\n>'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/Up.png" "$FIXTURES/a.png"
  "$INSTALL" "Upper" https://a.example/
  cmp -s "$ICONS/upper.png" "$FIXTURES/a.png"
}

@test "mask-icon (monochrome Safari pin) is not preferred over a real icon" {
  make_svg "$FIXTURES/mask.svg"
  make_png 192 192 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="192x192" href="/b.png"><link rel="mask-icon" href="/safari-pinned-tab.svg" color="#000000">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  route "https://a.example/safari-pinned-tab.svg" "$FIXTURES/mask.svg"
  "$INSTALL" "Mask" https://a.example/
  cmp -s "$ICONS/mask.png" "$FIXTURES/big.png"
}

@test "a large GIF candidate does not abort the search" {
  make_gif 128 128 "$FIXTURES/a.gif"
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="128x128" href="/a.gif">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/a.gif" "$FIXTURES/a.gif"
  route "https://a.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  run "$INSTALL" "Gif" https://a.example/
  [ "$status" -eq 0 ]
  cmp -s "$ICONS/gif.png" "$FIXTURES/touch.png"
}

@test "a favicon.ico embedding a large PNG does not abort the search" {
  make_ico_png 256 "$FIXTURES/favicon.ico"
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" href="/favicon.ico">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/favicon.ico" "$FIXTURES/favicon.ico"
  route "https://a.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  run "$INSTALL" "Ico" https://a.example/
  [ "$status" -eq 0 ]
  cmp -s "$ICONS/ico.png" "$FIXTURES/touch.png"
}

@test "dashboard icon smaller than 64px falls through to the site" {
  make_png 32 32 "$FIXTURES/dash.png"
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" ''
  route "$DASHBOARD/small.png" "$FIXTURES/dash.png"
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  "$INSTALL" "Small" https://a.example/
  cmp -s "$ICONS/small.png" "$FIXTURES/touch.png"
}

@test "auto icon size boundary: 64x64 accepted, 63x63 and 200x63 rejected" {
  make_png 64 64 "$FIXTURES/i64.png"
  route "$DASHBOARD/edge.png" "$FIXTURES/i64.png"
  "$INSTALL" "Edge" https://a.example/
  cmp -s "$ICONS/edge.png" "$FIXTURES/i64.png"

  make_png 63 63 "$FIXTURES/i63.png"
  route "$DASHBOARD/below.png" "$FIXTURES/i63.png"
  run "$INSTALL" "Below" https://b.example/
  [ "$(desktop_value below Icon)" = "web-browser" ]

  make_png 200 63 "$FIXTURES/wide.png"
  route "$DASHBOARD/wide.png" "$FIXTURES/wide.png"
  run "$INSTALL" "Wide" https://c.example/
  [ "$(desktop_value wide Icon)" = "web-browser" ]
}

@test "duplicate candidate URLs are fetched once" {
  make_png 16 16 "$FIXTURES/tiny.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/apple-touch-icon.png"><link rel="icon" href="https://a.example/apple-touch-icon.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/apple-touch-icon.png" "$FIXTURES/tiny.png"
  run "$INSTALL" "Dup" https://a.example/
  [ "$(grep -c 'https://a.example/apple-touch-icon.png$' "$CURL_LOG")" -eq 1 ]
}

@test "offline install prints only warnings on stderr (no shell noise)" {
  run --separate-stderr "$INSTALL" "Offline" https://a.example/
  [ "$status" -eq 0 ]
  [[ "$stderr" != *"No such file"* ]]
}

@test "Google fallback is https-only and a non-image answer falls back to the theme icon" {
  printf 'not an image' >"$FIXTURES/g.txt"
  route "$GOOGLE?domain=a.example&sz=256" "$FIXTURES/g.txt"
  run "$INSTALL" "G" https://a.example/
  [ "$status" -eq 0 ]
  [ "$(desktop_value g Icon)" = "web-browser" ]
  grep -q -- "--proto =https .*$GOOGLE?domain=a.example&sz=256" "$CURL_LOG"
  [[ "$output" != *"low-resolution"* ]]
}

@test "brave-browser is preferred over every other browser" {
  local b
  for b in brave chromium chromium-browser google-chrome-stable google-chrome microsoft-edge-stable vivaldi-stable; do add_browser "$b"; done
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "P" https://a.example/ "$FIXTURES/i.png"
  [[ "$(desktop_value p Exec)" == "brave-browser "* ]]
}

@test "auto-detection order and WM class prefix for each browser" {
  make_png 128 128 "$FIXTURES/i.png"
  remove_browser brave-browser
  local order=(brave chromium chromium-browser google-chrome-stable google-chrome microsoft-edge-stable vivaldi-stable)
  local prefixes=(brave chromium chromium chrome chrome msedge vivaldi)
  local b
  for b in "${order[@]}"; do add_browser "$b"; done
  local i
  for i in "${!order[@]}"; do
    "$INSTALL" "B$i" https://a.example/ "$FIXTURES/i.png"
    [[ "$(desktop_value "b$i" Exec)" == "${order[$i]} "* ]]
    [ "$(desktop_value "b$i" StartupWMClass)" = "${prefixes[$i]}-a.example__-Default" ]
    remove_browser "${order[$i]}"
  done
}

@test "WEBAPP_BROWSER as an absolute path uses the basename for the WM class" {
  mkdir -p "$BATS_TEST_TMPDIR/opt/brave.com/brave"
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/opt/brave.com/brave/brave"
  chmod +x "$BATS_TEST_TMPDIR/opt/brave.com/brave/brave"
  remove_browser brave-browser
  make_png 128 128 "$FIXTURES/i.png"
  WEBAPP_BROWSER="$BATS_TEST_TMPDIR/opt/brave.com/brave/brave" "$INSTALL" "Abs" https://a.example/ "$FIXTURES/i.png"
  [[ "$(desktop_value abs Exec)" == "$BATS_TEST_TMPDIR/opt/brave.com/brave/brave "* ]]
  [ "$(desktop_value abs StartupWMClass)" = "brave-a.example__-Default" ]
}

@test "rejects a URL whose authority is only a port" {
  run "$INSTALL" "A" "https://:8080/"
  [ "$status" -eq 1 ]
}

@test "accepts an @ in the path (not credentials)" {
  make_png 128 128 "$FIXTURES/i.png"
  run "$INSTALL" "Masto" "https://mastodon.social/@user" "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
  [ "$(desktop_value masto StartupWMClass)" = "brave-mastodon.social__@user-Default" ]
}

@test "short options -h and -V" {
  run "$INSTALL" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: webapp-install"* ]]
  run "$INSTALL" -V
  [ "$output" = "webapp-install 0.1.0" ]
  run "$REMOVE" -h
  [[ "$output" == *"Usage: webapp-remove"* ]]
  run "$REMOVE" -V
  [ "$output" = "webapp-remove 0.1.0" ]
}

@test "update-desktop-database is run on the applications dir, and is optional" {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\n' "$BATS_TEST_TMPDIR/udd-log" >"$STUBS/update-desktop-database"
  chmod +x "$STUBS/update-desktop-database"
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "U" https://a.example/ "$FIXTURES/i.png"
  [ "$(cat "$BATS_TEST_TMPDIR/udd-log")" = "$APPS" ]
  "$REMOVE" "U"
  [ "$(wc -l <"$BATS_TEST_TMPDIR/udd-log")" -eq 2 ]
  rm -f "$STUBS/update-desktop-database"
  run "$INSTALL" "V" https://a.example/ "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
}

@test "temporary files are cleaned up when installation fails" {
  printf 'hello' >"$FIXTURES/notes.png"
  local tmp="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$tmp"
  run env TMPDIR="$tmp" "$INSTALL" "Txt" https://a.example/ "$FIXTURES/notes.png"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "$tmp")" ]
  [ -z "$(ls -A "$APPS" 2>/dev/null)" ]
}

@test "explicit icon URL serving HTML is rejected" {
  html_page "$FIXTURES/err.html" ''
  route "https://cdn.example/logo.png" "$FIXTURES/err.html"
  run "$INSTALL" "R" https://a.example/ https://cdn.example/logo.png
  [ "$status" -eq 1 ]
  [[ "$output" == *"PNG or SVG"* ]]
  [ ! -f "$(desktop_file r)" ]
}

@test "list shows unescaped backslash names and sorts case-insensitively" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" 'Back\slash' https://a.example/ "$FIXTURES/i.png"
  "$INSTALL" "beta" https://b.example/ "$FIXTURES/i.png"
  "$INSTALL" "Charlie" https://c.example/ "$FIXTURES/i.png"
  run "$REMOVE"
  [ "${lines[1]}" = '  Back\slash' ]
  [ "${lines[2]}" = "  beta" ]
  [ "${lines[3]}" = "  Charlie" ]
  run "$REMOVE" 'Back\slash'
  [ "$status" -eq 0 ]
}

@test "webapp-remove -- allows a dash-leading name" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" -- "-Dash" https://a.example/ "$FIXTURES/i.png"
  run "$REMOVE" -- "-Dash"
  [ "$status" -eq 0 ]
  [ ! -e "$(desktop_file dash)" ]
}

@test "install.sh installs both tools into PREFIX/bin and warns about PATH" {
  cp "$(PATH=/usr/bin:/bin command -v install)" "$SYSBIN/install"
  run env PREFIX="$BATS_TEST_TMPDIR/pfx" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -x "$BATS_TEST_TMPDIR/pfx/bin/webapp-install" ]
  [ -x "$BATS_TEST_TMPDIR/pfx/bin/webapp-remove" ]
  cmp -s "$BATS_TEST_TMPDIR/pfx/bin/webapp-install" "$INSTALL"
  [[ "$output" == *"not in your PATH"* ]]
  run env PREFIX="$BATS_TEST_TMPDIR/pfx" PATH="$BATS_TEST_TMPDIR/pfx/bin:$PATH" "$REPO_ROOT/install.sh"
  [[ "$output" != *"not in your PATH"* ]]
}

@test "install.sh defaults to ~/.local and warns when curl is missing" {
  cp "$(PATH=/usr/bin:/bin command -v install)" "$SYSBIN/install"
  rm -f "$STUBS/curl"
  run --separate-stderr "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -x "$HOME/.local/bin/webapp-install" ]
  [[ "$stderr" == *"curl is required"* ]]
}

@test "uninstall.sh removes both tools and keeps installed web apps" {
  cp "$(PATH=/usr/bin:/bin command -v install)" "$SYSBIN/install"
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Keep" https://a.example/ "$FIXTURES/i.png"
  PREFIX="$BATS_TEST_TMPDIR/pfx" "$REPO_ROOT/install.sh"
  run env PREFIX="$BATS_TEST_TMPDIR/pfx" "$REPO_ROOT/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/pfx/bin/webapp-install" ]
  [ ! -e "$BATS_TEST_TMPDIR/pfx/bin/webapp-remove" ]
  [ -e "$(desktop_file keep)" ]
  run env PREFIX="$BATS_TEST_TMPDIR/pfx" "$REPO_ROOT/uninstall.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unquoted link attributes (minified HTML) are parsed" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel=apple-touch-icon href=/static/t.png>'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/static/t.png" "$FIXTURES/touch.png"
  "$INSTALL" "Unq" https://a.example/
  cmp -s "$ICONS/unq.png" "$FIXTURES/touch.png"
}

@test "uppercase host: WM class host is lowercased like Chromium" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Case" "https://Web.WhatsApp.com/" "$FIXTURES/i.png"
  [ "$(desktop_value case StartupWMClass)" = "brave-web.whatsapp.com__-Default" ]
}

@test "data-href before href does not hide the real href" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" data-href="/nope.png" href="/static/t.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/static/t.png" "$FIXTURES/touch.png"
  "$INSTALL" "Dh" https://a.example/
  cmp -s "$ICONS/dh.png" "$FIXTURES/touch.png"
}

# --- Review findings ---------------------------------------------------------

@test "list survives a webapp entry without Name= and falls back to its slug" {
  mkdir -p "$APPS"
  printf '[Desktop Entry]\nName=Good\n' >"$APPS/webapp-good.desktop"
  printf '[Desktop Entry]\nType=Application\n' >"$APPS/webapp-broken.desktop"
  run "$REMOVE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"  Good"* ]]
  [[ "$output" == *"  broken"* ]]
}

@test "a relative WEBAPP_BROWSER path is rejected (the launcher runs from another dir)" {
  mkdir -p "$BATS_TEST_TMPDIR/work"
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/work/mybrowser"
  chmod +x "$BATS_TEST_TMPDIR/work/mybrowser"
  cd "$BATS_TEST_TMPDIR/work"
  run env WEBAPP_BROWSER=./mybrowser "$INSTALL" "A" https://a.example/
  [ "$status" -eq 1 ]
}

@test "Google fallback restricts redirects to https" {
  run "$INSTALL" "G" https://a.example/
  grep -q -- "--proto-redir =https .*$GOOGLE?domain=a.example&sz=256" "$CURL_LOG"
}

@test "icon links to private or loopback hosts are not fetched for a public site" {
  local h
  for h in localhost 127.0.0.1 10.0.0.1 192.168.1.1 172.16.0.1 169.254.169.254 "[::1]" 0.0.0.0; do
    html_page "$FIXTURES/page.html" "<link rel=\"apple-touch-icon\" href=\"http://$h/x.png\">"
    route "https://pub.example/" "$FIXTURES/page.html"
    run "$INSTALL" "Pub" https://pub.example/
    [ "$status" -eq 0 ]
    run ! grep -qF "http://$h/x.png" "$CURL_LOG"
    : >"$CURL_ROUTES"
    : >"$CURL_LOG"
  done
}

@test "a local web app may use icons from its own local host" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "http://localhost:3000/" "$FIXTURES/page.html"
  route "http://localhost:3000/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Local" http://localhost:3000/
  cmp -s "$ICONS/local.png" "$FIXTURES/a.png"
}

@test "172.32.x is public and not treated as private" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="http://172.32.0.1/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "http://172.32.0.1/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Pub" https://pub.example/
  cmp -s "$ICONS/pub.png" "$FIXTURES/a.png"
}

@test "reinstall while offline keeps the previously installed icon" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Keep" https://a.example/ "$FIXTURES/i.png"
  run "$INSTALL" "Keep" https://a.example/
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping the current icon"* ]]
  cmp -s "$ICONS/keep.png" "$FIXTURES/i.png"
  [ "$(desktop_value keep Icon)" = "$ICONS/keep.png" ]
}

@test "IPv6 host keeps its brackets in the WM class" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "V6" "http://[::1]:8080/app" "$FIXTURES/i.png"
  [ "$(desktop_value v6 StartupWMClass)" = "brave-[::1]__app-Default" ]
}

@test "no staging files are left in the data directories" {
  make_png 128 128 "$FIXTURES/i.png"
  local tmp="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$tmp"
  printf '#!/bin/sh\nls -A "%s" "%s" >"%s"\n' "$APPS" "$ICONS" "$BATS_TEST_TMPDIR/snapshot" >"$STUBS/update-desktop-database"
  chmod +x "$STUBS/update-desktop-database"
  TMPDIR="$tmp" "$INSTALL" "Atomic" https://a.example/ "$FIXTURES/i.png"
  run ! grep -q '^\.webapp-' "$BATS_TEST_TMPDIR/snapshot"
  [ -z "$(ls -A "$tmp")" ]
}

# --- Review findings, round 2 -------------------------------------------------

@test "curl URL globbing is disabled for every download" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  run "$INSTALL" "Glob" https://a.example/
  run ! grep -v -- "--globoff" "$CURL_LOG"
}

@test "icon links with curl glob characters in the host are not fetched" {
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="http://{a.invalid,127.0.0.1:8080}/x.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  run "$INSTALL" "Pub" https://pub.example/
  [ "$status" -eq 0 ]
  run ! grep -qF "127.0.0.1" "$CURL_LOG"
}

@test "numeric, octal, hex and trailing-dot spellings of local hosts are not fetched" {
  local h
  for h in 2130706433 0x7f.1 0x7f000001 0177.0.0.1 localhost. 0 0.0.0.1 100.64.0.1 127.000.0.1; do
    html_page "$FIXTURES/page.html" "<link rel=\"apple-touch-icon\" href=\"http://$h:631/x.png\">"
    route "https://pub.example/" "$FIXTURES/page.html"
    run "$INSTALL" "Pub" https://pub.example/
    [ "$status" -eq 0 ]
    run ! grep -qF "http://$h:631/x.png" "$CURL_LOG"
    : >"$CURL_ROUTES"
    : >"$CURL_LOG"
  done
}

@test "a canonical public IPv4 icon host is still fetched" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="http://8.8.8.8/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "http://8.8.8.8/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Pub" https://pub.example/
  cmp -s "$ICONS/pub.png" "$FIXTURES/a.png"
}

@test "a candidate redirecting to a private host is not followed" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "https://pub.example/t.png" "redirect:http://192.168.1.1/apply.cgi"
  route "http://192.168.1.1/apply.cgi" "$FIXTURES/a.png"
  run "$INSTALL" "Pub" https://pub.example/
  [ "$status" -eq 0 ]
  run ! grep -qF "192.168.1.1" "$CURL_LOG"
}

@test "a candidate redirecting to a public host is followed" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "https://pub.example/t.png" "redirect:https://cdn.example/t.png"
  route "https://cdn.example/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Pub" https://pub.example/
  cmp -s "$ICONS/pub.png" "$FIXTURES/a.png"
}

@test "redirect loops stop after a few hops" {
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/loop">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "https://pub.example/loop" "redirect:https://pub.example/loop"
  run "$INSTALL" "Pub" https://pub.example/
  [ "$status" -eq 0 ]
  [ "$(grep -c 'https://pub.example/loop$' "$CURL_LOG")" -le 6 ]
}

@test "staging files are removed when the install fails after staging" {
  make_png 128 128 "$FIXTURES/i.png"
  printf '#!/bin/sh\nexit 1\n' >"$STUBS/chmod"
  chmod +x "$STUBS/chmod"
  run "$INSTALL" "Fail" https://a.example/ "$FIXTURES/i.png"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$ICONS" 2>/dev/null)" ]
  [ -z "$(ls -A "$APPS" 2>/dev/null)" ]
}

@test "the Google fallback is skipped for private hosts" {
  run "$INSTALL" "Lan" http://192.168.1.10/
  [ "$status" -eq 0 ]
  run ! grep -q "google.com" "$CURL_LOG"
  [ "$(desktop_value lan Icon)" = "web-browser" ]
}

@test "an icon listing several sizes is ranked by its largest one" {
  make_png 96 96 "$FIXTURES/mid.png"
  make_png 256 256 "$FIXTURES/multi.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="96x96" href="/mid.png"><link rel="icon" sizes="16x16 32x32 256x256" href="/multi.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/mid.png" "$FIXTURES/mid.png"
  route "https://a.example/multi.png" "$FIXTURES/multi.png"
  "$INSTALL" "Multi" https://a.example/
  cmp -s "$ICONS/multi.png" "$FIXTURES/multi.png"
}

# --- Review findings, round 3 -------------------------------------------------

@test "icon links with userinfo cannot smuggle a private host" {
  local href
  for href in "http://public.com:80@127.0.0.1:8080/x.png" "http://a:b@[::1]/x.png"; do
    html_page "$FIXTURES/page.html" "<link rel=\"apple-touch-icon\" href=\"$href\">"
    route "https://pub.example/" "$FIXTURES/page.html"
    run "$INSTALL" "Pub" https://pub.example/
    [ "$status" -eq 0 ]
    run ! grep -qF "$href" "$CURL_LOG"
    : >"$CURL_ROUTES"
    : >"$CURL_LOG"
  done
}

@test "a redirect with userinfo is not followed" {
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "https://pub.example/t.png" "redirect:http://a:b@10.0.0.1/x.png"
  run "$INSTALL" "Pub" https://pub.example/
  [ "$status" -eq 0 ]
  run ! grep -qF "10.0.0.1" "$CURL_LOG"
}

@test "non-ASCII look-alike hosts are rejected regardless of the locale" {
  local h
  for h in "ｌｏｃａｌｈｏｓｔ" "ⓛocalhost" "１２７.0.0.1"; do
    html_page "$FIXTURES/page.html" "<link rel=\"apple-touch-icon\" href=\"http://$h:1/x.png\">"
    route "https://pub.example/" "$FIXTURES/page.html"
    run env LC_ALL=en_US.UTF-8 "$INSTALL" "Pub" https://pub.example/
    [ "$status" -eq 0 ]
    run ! grep -qF "$h" "$CURL_LOG"
    : >"$CURL_ROUTES"
    : >"$CURL_LOG"
  done
}

@test "public domains starting with 0x are not treated as private" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="https://0xide.com/t.png">'
  route "https://pub.example/" "$FIXTURES/page.html"
  route "https://0xide.com/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Pub" https://pub.example/
  cmp -s "$ICONS/pub.png" "$FIXTURES/a.png"
}
