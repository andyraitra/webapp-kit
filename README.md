# webapp-kit

[![CI](https://github.com/andyraitra/webapp-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/andyraitra/webapp-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Turn any website into a real desktop app on Linux: its own window (no tabs, no
address bar), its own launcher entry, its own icon and its own place in the dock.

Inspired by [Omarchy](https://omarchy.org)'s web apps, packaged as two small,
dependency-free shell commands that work on any freedesktop desktop (COSMIC,
GNOME, KDE, Hyprland, ...).

```bash
webapp-install "WhatsApp" https://web.whatsapp.com/
webapp-remove "WhatsApp"
```

> **Status: 0.x.** Usable day to day, but the interface may still change before 1.0.

## Requirements

- A Chromium-based browser: Brave, Chromium, Google Chrome, Microsoft Edge or Vivaldi
  (Firefox has no `--app` mode)
- `bash` 4+, `curl`, `file` (preinstalled on most distributions)

## Install

```bash
git clone https://github.com/andyraitra/webapp-kit.git
cd webapp-kit
./install.sh            # installs into ~/.local/bin
```

Use `PREFIX=/some/dir ./install.sh` to install elsewhere, and `./uninstall.sh` to
remove the commands (your web apps are kept).

## Usage

```bash
webapp-install "<Name>" <url> [icon]
```

```bash
webapp-install "ChatGPT" https://chatgpt.com/
webapp-install "Gmail" https://mail.google.com/
webapp-install "Notion" https://www.notion.so/ ~/Pictures/notion.png   # custom icon (file or URL)

webapp-remove              # list installed web apps
webapp-remove "Gmail"      # remove one
```

Running `webapp-install` again with the same name updates the app.

| Variable | Effect |
| --- | --- |
| `WEBAPP_BROWSER` | Browser command to use, e.g. `google-chrome-stable` (default: first one found) |
| `XDG_DATA_HOME` | Where launchers and icons are stored (default: `~/.local/share`) |

## How it works

`webapp-install` writes a standard
[desktop entry](https://specifications.freedesktop.org/desktop-entry-spec/latest/)
to `~/.local/share/applications/webapp-<name>.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=WhatsApp
Exec=brave-browser --new-window --ozone-platform-hint=auto "--app=https://web.whatsapp.com/"
Icon=/home/you/.local/share/icons/webapps/whatsapp.png
StartupWMClass=brave-web.whatsapp.com__-Default
```

- `--app=URL` opens a dedicated window without browser UI. The web app shares your
  browser profile, so you stay logged in.
- `StartupWMClass` matches the window id Chromium gives to `--app` windows
  (`<browser>-<host>_<path>-Default`), so the dock shows the app's icon instead of the browser's.
- The icon is picked automatically, best first:
  1. the [dashboard-icons](https://github.com/homarr-labs/dashboard-icons) set (HD icons, matched by name);
  2. the icon the site declares itself (`apple-touch-icon`, then the largest `<link rel="icon">`, SVG included);
  3. Google's favicon service, as a low-resolution last resort (a warning is printed);
  4. the generic `web-browser` theme icon if everything else fails (e.g. offline).

  Downloaded icons must be real PNG (at least 64×64) or SVG files. When nothing is
  found on a reinstall (e.g. offline), the current icon is kept.

### Privacy

Automatic icon lookup contacts jsDelivr (dashboard-icons), the site itself and, as a
last resort, Google's favicon service with the site's domain. Pass an icon as third
argument to skip the lookup entirely.

### Security

Names and URLs are validated before anything is written: control characters are
rejected, only `http(s)` URLs made of RFC 3986 characters are accepted, and the URL is
quoted and `%`-escaped in `Exec`, so a crafted name or URL cannot inject commands into
the launcher. Downloads are limited to http(s), 15 s and 5 MB, and icon links that a
public page points at `localhost` or private network addresses are never fetched. See
[SECURITY.md](SECURITY.md) to report a vulnerability.

## Troubleshooting

- **The old icon still shows**: the desktop caches icons. Reopen the launcher,
  unpin/re-pin the app from the dock, or log out and back in.
- **The window shows the browser icon in the dock**: the window id did not match
  `StartupWMClass`. Please [open an issue](https://github.com/andyraitra/webapp-kit/issues)
  with your browser and desktop.
- **"no high-resolution icon found"**: pass an icon as third argument.

## En français

`webapp-kit` transforme n'importe quel site en vraie application Linux : fenêtre dédiée,
entrée dans le lanceur, icône propre et place dans le dock.
Installation : `./install.sh`. Utilisation : `webapp-install "Nom" https://site/ [icône]`
et `webapp-remove "Nom"` (sans argument : liste des webapps).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Development uses `make check` (shellcheck,
shfmt, bats); tool versions are pinned in `mise.toml`.

## License

[MIT](LICENSE) © Andy Raitra Rakoto
