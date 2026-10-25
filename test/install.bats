#!/usr/bin/env bats

load helper

setup() {
  common_setup
}

# --- CLI -------------------------------------------------------------------

@test "--version prints the version" {
  run "$INSTALL" --version
  [ "$status" -eq 0 ]
  [ "$output" = "webapp-install 0.1.0" ]
}

@test "--help prints usage and exits 0" {
  run "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: webapp-install"* ]]
}

@test "missing arguments prints usage and fails" {
  run "$INSTALL" "OnlyName"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: webapp-install"* ]]
}

@test "too many arguments fails" {
  run "$INSTALL" "A" https://a.example/ icon.png extra
  [ "$status" -eq 2 ]
}

@test "unknown option fails" {
  run "$INSTALL" --frobnicate "A" https://a.example/
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "-- allows a name starting with a dash" {
  make_png 128 128 "$FIXTURES/i.png"
  run "$INSTALL" -- "-Dash" https://a.example/ "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
  [ -f "$(desktop_file dash)" ]
}

# --- Desktop entry ---------------------------------------------------------

@test "installs a valid desktop entry for a web app" {
  make_png 512 512 "$FIXTURES/whatsapp.png"
  route "$DASHBOARD/whatsapp.png" "$FIXTURES/whatsapp.png"

  run "$INSTALL" "WhatsApp" https://web.whatsapp.com/
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed WhatsApp"* ]]

  [ "$(desktop_value whatsapp Name)" = "WhatsApp" ]
  [ "$(desktop_value whatsapp Type)" = "Application" ]
  [ "$(desktop_value whatsapp Exec)" = 'brave-browser --new-window --ozone-platform-hint=auto "--app=https://web.whatsapp.com/"' ]
  [ "$(desktop_value whatsapp StartupWMClass)" = "brave-web.whatsapp.com__-Default" ]
  [ "$(desktop_value whatsapp Icon)" = "$ICONS/whatsapp.png" ]
  [ "$(desktop_value whatsapp Terminal)" = "false" ]
  [ -f "$ICONS/whatsapp.png" ]
}

@test "generated desktop entry passes desktop-file-validate" {
  command -v desktop-file-validate >/dev/null 2>&1 || PATH="$PATH:/usr/bin"
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Mon Truc" "https://example.org/a?b=1&c=%20#x" "$FIXTURES/i.png"
  run desktop-file-validate "$(desktop_file mon-truc)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "percent signs in the URL are escaped as %% in Exec" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Pct" "https://a.example/search?q=a%20b" "$FIXTURES/i.png"
  [ "$(desktop_value pct Exec)" = 'brave-browser --new-window --ozone-platform-hint=auto "--app=https://a.example/search?q=a%%20b"' ]
}

@test "WM class keeps the path, drops port, query and fragment" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Mail" "https://mail.example.com:8443/mail/u/0/?tab=1#inbox" "$FIXTURES/i.png"
  [ "$(desktop_value mail StartupWMClass)" = "brave-mail.example.com__mail_u_0_-Default" ]
}

@test "URL without a path gets the root path in the WM class" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Bare" "https://bare.example" "$FIXTURES/i.png"
  [ "$(desktop_value bare StartupWMClass)" = "brave-bare.example__-Default" ]
}

@test "backslashes in the name are escaped in the desktop entry" {
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" 'Back\slash' https://a.example/ "$FIXTURES/i.png"
  [ "$(desktop_value back-slash Name)" = 'Back\\slash' ]
}

@test "unicode names are kept, slug is ASCII" {
  make_png 128 128 "$FIXTURES/i.png"
  run "$INSTALL" "Café Crème" https://cafe.example/ "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
  [ "$(desktop_value caf-cr-me Name)" = "Café Crème" ]
}

@test "XDG_DATA_HOME is respected" {
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg"
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Xdg" https://a.example/ "$FIXTURES/i.png"
  [ -f "$XDG_DATA_HOME/applications/webapp-xdg.desktop" ]
  [ -f "$XDG_DATA_HOME/icons/webapps/xdg.png" ]
}

@test "reinstalling replaces the entry and the old icon format" {
  make_svg "$FIXTURES/i.svg"
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "Re" https://a.example/ "$FIXTURES/i.svg"
  [ -f "$ICONS/re.svg" ]
  run "$INSTALL" "Re" https://b.example/ "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated Re"* ]]
  [ ! -f "$ICONS/re.svg" ]
  [ -f "$ICONS/re.png" ]
  [[ "$(desktop_value re Exec)" == *"https://b.example/"* ]]
}

@test "no temporary files are left behind" {
  make_png 128 128 "$FIXTURES/i.png"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  "$INSTALL" "Tmp" https://a.example/ "$FIXTURES/i.png"
  [ -z "$(ls -A "$TMPDIR")" ]
  [ "$(ls -A "$APPS")" = "webapp-tmp.desktop" ]
}

# --- Name validation -------------------------------------------------------

@test "rejects an empty name" {
  run "$INSTALL" "" https://a.example/
  [ "$status" -eq 1 ]
  [[ "$output" == *"name"* ]]
}

@test "rejects a name with no usable characters" {
  run "$INSTALL" "!!!" https://a.example/
  [ "$status" -eq 1 ]
  [[ "$output" == *"name"* ]]
}

@test "rejects a newline in the name (desktop entry injection)" {
  run "$INSTALL" $'Evil\nExec=rm -rf ~' https://a.example/
  [ "$status" -eq 1 ]
  [ ! -d "$APPS" ] || [ -z "$(ls -A "$APPS")" ]
}

@test "rejects a tab in the name" {
  run "$INSTALL" $'Tab\there' https://a.example/
  [ "$status" -eq 1 ]
}

@test "rejects a name longer than 64 characters" {
  run "$INSTALL" "$(printf 'a%.0s' {1..65})" https://a.example/
  [ "$status" -eq 1 ]
  [[ "$output" == *"64"* ]]
}

@test "accepts a name of exactly 64 characters" {
  make_png 128 128 "$FIXTURES/i.png"
  run "$INSTALL" "$(printf 'a%.0s' {1..64})" https://a.example/ "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
}

# --- URL validation --------------------------------------------------------

@test "rejects a URL without scheme" {
  run "$INSTALL" "A" web.whatsapp.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"http"* ]]
}

@test "rejects javascript: URLs" {
  run "$INSTALL" "A" "javascript:alert(1)"
  [ "$status" -eq 1 ]
}

@test "rejects file: URLs" {
  run "$INSTALL" "A" "file:///etc/passwd"
  [ "$status" -eq 1 ]
}

@test "rejects a URL with a space" {
  run "$INSTALL" "A" "https://a.example/a b"
  [ "$status" -eq 1 ]
}

@test "rejects a URL with a double quote (Exec injection)" {
  run "$INSTALL" "A" 'https://a.example/"; rm -rf ~; "'
  [ "$status" -eq 1 ]
}

@test "rejects a URL with backtick or dollar (Exec injection)" {
  run "$INSTALL" "A" "https://a.example/\`id\`"
  [ "$status" -eq 1 ]
  run "$INSTALL" "A" "https://a.example/\$(id)"
  [ "$status" -eq 1 ]
}

@test "rejects a URL with credentials" {
  run "$INSTALL" "A" "https://user:pass@a.example/"
  [ "$status" -eq 1 ]
}

@test "rejects a URL with an empty host" {
  run "$INSTALL" "A" "https:///path"
  [ "$status" -eq 1 ]
}

@test "accepts uppercase scheme" {
  make_png 128 128 "$FIXTURES/i.png"
  run "$INSTALL" "Up" "HTTPS://a.example/" "$FIXTURES/i.png"
  [ "$status" -eq 0 ]
}

# --- Browser selection -----------------------------------------------------

@test "fails clearly when no Chromium-based browser is installed" {
  remove_browser brave-browser
  run "$INSTALL" "A" https://a.example/
  [ "$status" -eq 1 ]
  [[ "$output" == *"Chromium-based browser"* ]]
}

@test "detects chromium when brave is absent" {
  remove_browser brave-browser
  add_browser chromium
  make_png 128 128 "$FIXTURES/i.png"
  "$INSTALL" "C" https://a.example/ "$FIXTURES/i.png"
  [[ "$(desktop_value c Exec)" == "chromium "* ]]
  [ "$(desktop_value c StartupWMClass)" = "chromium-a.example__-Default" ]
}

@test "WEBAPP_BROWSER selects the browser and its WM class prefix" {
  add_browser google-chrome-stable
  add_browser microsoft-edge-stable
  make_png 128 128 "$FIXTURES/i.png"
  WEBAPP_BROWSER=google-chrome-stable "$INSTALL" "G" https://a.example/ "$FIXTURES/i.png"
  [ "$(desktop_value g StartupWMClass)" = "chrome-a.example__-Default" ]
  WEBAPP_BROWSER=microsoft-edge-stable "$INSTALL" "E" https://a.example/ "$FIXTURES/i.png"
  [ "$(desktop_value e StartupWMClass)" = "msedge-a.example__-Default" ]
}

@test "WEBAPP_BROWSER that is not installed fails" {
  run env WEBAPP_BROWSER=nope-browser "$INSTALL" "A" https://a.example/
  [ "$status" -eq 1 ]
  [[ "$output" == *"nope-browser"* ]]
}

@test "WEBAPP_BROWSER with shell metacharacters is rejected" {
  run env WEBAPP_BROWSER='brave-browser; rm -rf ~' "$INSTALL" "A" https://a.example/
  [ "$status" -eq 1 ]
}

# --- Icon: explicit --------------------------------------------------------

@test "explicit local SVG icon is used as .svg" {
  make_svg "$FIXTURES/logo.svg"
  "$INSTALL" "Svg" https://a.example/ "$FIXTURES/logo.svg"
  [ "$(desktop_value svg Icon)" = "$ICONS/svg.svg" ]
  [ ! -s "$CURL_LOG" ]
}

@test "explicit local icon that does not exist fails without leaving files" {
  run "$INSTALL" "Missing" https://a.example/ "$FIXTURES/nope.png"
  [ "$status" -eq 1 ]
  [ ! -f "$(desktop_file missing)" ]
}

@test "explicit local icon that is not an image fails" {
  printf 'hello' >"$FIXTURES/notes.png"
  run "$INSTALL" "Txt" https://a.example/ "$FIXTURES/notes.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PNG or SVG"* ]]
  [ ! -f "$(desktop_file txt)" ]
}

@test "explicit small PNG icon is accepted (user's choice)" {
  make_png 16 16 "$FIXTURES/tiny.png"
  run "$INSTALL" "Tiny" https://a.example/ "$FIXTURES/tiny.png"
  [ "$status" -eq 0 ]
}

@test "explicit icon URL is downloaded" {
  make_png 256 256 "$FIXTURES/remote.png"
  route "https://cdn.example/logo.png" "$FIXTURES/remote.png"
  run "$INSTALL" "Remote" https://a.example/ https://cdn.example/logo.png
  [ "$status" -eq 0 ]
  [ -f "$ICONS/remote.png" ]
}

@test "explicit icon URL that 404s fails" {
  run "$INSTALL" "Remote" https://a.example/ https://cdn.example/missing.png
  [ "$status" -eq 1 ]
  [ ! -f "$(desktop_file remote)" ]
}

@test "downloads are restricted to http(s), size-limited and time-limited" {
  make_png 256 256 "$FIXTURES/remote.png"
  route "https://cdn.example/logo.png" "$FIXTURES/remote.png"
  "$INSTALL" "Remote" https://a.example/ https://cdn.example/logo.png
  grep -q -- "--proto =http,https" "$CURL_LOG"
  grep -q -- "--proto-redir =http,https" "$CURL_LOG"
  grep -q -- "--max-filesize" "$CURL_LOG"
  grep -q -- "--max-time" "$CURL_LOG"
}

# --- Icon: automatic resolution --------------------------------------------

@test "dashboard-icons is tried first" {
  make_png 512 512 "$FIXTURES/gh.png"
  route "$DASHBOARD/github.png" "$FIXTURES/gh.png"
  "$INSTALL" "GitHub" https://github.com/
  [ -f "$ICONS/github.png" ]
  [ "$(head -1 "$CURL_LOG" | grep -c dashboard-icons)" -eq 1 ]
  [ "$(wc -l <"$CURL_LOG")" -eq 1 ]
}

@test "site apple-touch-icon is used when dashboard-icons has none" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" '<link rel="icon" href="/favicon.ico"><link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />'
  route "https://fs.example/" "$FIXTURES/page.html"
  route "https://fs.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  run "$INSTALL" "FrenchStream" https://fs.example/
  [ "$status" -eq 0 ]
  [ -f "$ICONS/frenchstream.png" ]
  [ "$(desktop_value frenchstream Icon)" = "$ICONS/frenchstream.png" ]
}

@test "largest sized icon is preferred when there is no apple-touch-icon" {
  make_png 32 32 "$FIXTURES/small.png"
  make_png 192 192 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" "<LINK REL='icon' sizes='32x32' href='/s.png'><link rel=\"icon\" sizes=\"192x192\" href=\"/b.png\">"
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/s.png" "$FIXTURES/small.png"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  "$INSTALL" "Sized" https://a.example/
  cmp -s "$ICONS/sized.png" "$FIXTURES/big.png"
}

@test "site SVG icon is stored as .svg" {
  make_svg "$FIXTURES/fav.svg"
  html_page "$FIXTURES/page.html" '<link rel="icon" type="image/svg+xml" href="/favicon.svg">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/favicon.svg" "$FIXTURES/fav.svg"
  "$INSTALL" "Vector" https://a.example/
  [ -f "$ICONS/vector.svg" ]
  [ "$(desktop_value vector Icon)" = "$ICONS/vector.svg" ]
}

@test "protocol-relative and relative icon links are resolved against the final page URL" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="img/touch.png">'
  route "https://a.example/app" "$FIXTURES/page.html" "https://a.example/app/home"
  route "https://a.example/app/img/touch.png" "$FIXTURES/a.png"
  "$INSTALL" "Rel" https://a.example/app
  [ -f "$ICONS/rel.png" ]

  html_page "$FIXTURES/page2.html" '<link rel="apple-touch-icon" href="//cdn.example/t.png">'
  route "https://b.example/" "$FIXTURES/page2.html"
  route "https://cdn.example/t.png" "$FIXTURES/a.png"
  "$INSTALL" "Proto" https://b.example/
  [ -f "$ICONS/proto.png" ]
}

@test "HTML entities in icon links are decoded" {
  make_png 128 128 "$FIXTURES/a.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/icon?v=2&amp;s=180">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/icon?v=2&s=180" "$FIXTURES/a.png"
  "$INSTALL" "Ent" https://a.example/
  [ -f "$ICONS/ent.png" ]
}

@test "data: and javascript: icon links are ignored" {
  html_page "$FIXTURES/page.html" '<link rel="icon" sizes="512x512" href="data:image/png;base64,AAAA"><link rel="icon" href="javascript:x">'
  route "https://a.example/" "$FIXTURES/page.html"
  run "$INSTALL" "Data" https://a.example/
  [ "$status" -eq 0 ]
  run ! grep -q "data:image" "$CURL_LOG"
  run ! grep -q "javascript:" "$CURL_LOG"
}

@test "conventional /apple-touch-icon.png is tried when the page declares nothing" {
  make_png 180 180 "$FIXTURES/touch.png"
  html_page "$FIXTURES/page.html" ''
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/apple-touch-icon.png" "$FIXTURES/touch.png"
  "$INSTALL" "Conv" https://a.example/
  cmp -s "$ICONS/conv.png" "$FIXTURES/touch.png"
}

@test "an HTML error page served as icon is rejected and the next candidate is tried" {
  make_png 192 192 "$FIXTURES/big.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/broken.png"><link rel="icon" sizes="192x192" href="/b.png">'
  html_page "$FIXTURES/error.html" ''
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/broken.png" "$FIXTURES/error.html"
  route "https://a.example/b.png" "$FIXTURES/big.png"
  "$INSTALL" "Next" https://a.example/
  cmp -s "$ICONS/next.png" "$FIXTURES/big.png"
}

@test "a 16px site icon is rejected in favour of the Google fallback with a warning" {
  make_png 16 16 "$FIXTURES/tiny.png"
  make_png 64 64 "$FIXTURES/google.png"
  html_page "$FIXTURES/page.html" '<link rel="apple-touch-icon" href="/t.png">'
  route "https://a.example/" "$FIXTURES/page.html"
  route "https://a.example/t.png" "$FIXTURES/tiny.png"
  route "$GOOGLE?domain=a.example&sz=256" "$FIXTURES/google.png"
  run "$INSTALL" "Low" https://a.example/
  [ "$status" -eq 0 ]
  [[ "$output" == *"low-resolution"* ]]
  cmp -s "$ICONS/low.png" "$FIXTURES/google.png"
}

@test "offline: install still succeeds with a generic themed icon" {
  run "$INSTALL" "Offline" https://a.example/
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  [ "$(desktop_value offline Icon)" = "web-browser" ]
  [ ! -e "$ICONS/offline.png" ]
}
