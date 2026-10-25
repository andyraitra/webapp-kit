#!/usr/bin/env bats

load helper

setup() {
  common_setup
  make_png 128 128 "$FIXTURES/i.png"
}

@test "--version prints the version" {
  run "$REMOVE" --version
  [ "$status" -eq 0 ]
  [ "$output" = "webapp-remove 0.1.0" ]
}

@test "--help prints usage" {
  run "$REMOVE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: webapp-remove"* ]]
}

@test "unknown option fails" {
  run "$REMOVE" --nope
  [ "$status" -eq 2 ]
}

@test "too many arguments fails" {
  run "$REMOVE" a b
  [ "$status" -eq 2 ]
}

@test "lists nothing when no web app is installed" {
  run "$REMOVE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No web apps installed"* ]]
}

@test "lists installed web apps sorted by name" {
  "$INSTALL" "Zed" https://z.example/ "$FIXTURES/i.png"
  "$INSTALL" "Alpha" https://a.example/ "$FIXTURES/i.png"
  run "$REMOVE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Installed web apps:" ]
  [ "${lines[1]}" = "  Alpha" ]
  [ "${lines[2]}" = "  Zed" ]
}

@test "list ignores desktop entries not created by webapp-kit" {
  mkdir -p "$APPS"
  printf '[Desktop Entry]\nName=Other\n' >"$APPS/other.desktop"
  run "$REMOVE"
  [[ "$output" != *"Other"* ]]
}

@test "removes the desktop entry and its icon" {
  "$INSTALL" "WhatsApp" https://web.whatsapp.com/ "$FIXTURES/i.png"
  run "$REMOVE" "WhatsApp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed WhatsApp"* ]]
  [ ! -e "$(desktop_file whatsapp)" ]
  [ ! -e "$ICONS/whatsapp.png" ]
}

@test "removes an SVG icon too" {
  make_svg "$FIXTURES/i.svg"
  "$INSTALL" "Vec" https://a.example/ "$FIXTURES/i.svg"
  "$REMOVE" "Vec"
  [ ! -e "$ICONS/vec.svg" ]
}

@test "name matching is case-insensitive through the slug" {
  "$INSTALL" "Mon Truc" https://a.example/ "$FIXTURES/i.png"
  run "$REMOVE" "mon truc"
  [ "$status" -eq 0 ]
  [ ! -e "$(desktop_file mon-truc)" ]
}

@test "removing an unknown web app fails" {
  run "$REMOVE" "Ghost"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ghost"* ]]
}

@test "removing with an unusable name fails without touching other files" {
  "$INSTALL" "Keep" https://a.example/ "$FIXTURES/i.png"
  run "$REMOVE" "!!!"
  [ "$status" -eq 1 ]
  [ -e "$(desktop_file keep)" ]
}

@test "does not remove other apps' icons sharing a prefix" {
  "$INSTALL" "Mail" https://a.example/ "$FIXTURES/i.png"
  "$INSTALL" "Mail Pro" https://b.example/ "$FIXTURES/i.png"
  "$REMOVE" "Mail"
  [ -e "$ICONS/mail-pro.png" ]
  [ -e "$(desktop_file mail-pro)" ]
}

@test "removes entries created by the pre-release scripts" {
  mkdir -p "$APPS" "$ICONS"
  printf '[Desktop Entry]\nName=FrenchStream\nExec=brave-browser --app=https://x/\n' >"$APPS/webapp-frenchstream.desktop"
  cp "$FIXTURES/i.png" "$ICONS/frenchstream.png"
  run "$REMOVE" "FrenchStream"
  [ "$status" -eq 0 ]
  [ ! -e "$APPS/webapp-frenchstream.desktop" ]
  [ ! -e "$ICONS/frenchstream.png" ]
}

@test "respects XDG_DATA_HOME" {
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/xdg"
  "$INSTALL" "Xdg" https://a.example/ "$FIXTURES/i.png"
  "$REMOVE" "Xdg"
  [ ! -e "$XDG_DATA_HOME/applications/webapp-xdg.desktop" ]
}
