# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-25

### Added

- `webapp-install` to install a website as a desktop application, with automatic
  browser detection (Brave, Chromium, Chrome, Edge, Vivaldi) and `StartupWMClass`
  so each app gets its own dock icon.
- Automatic icon lookup: dashboard-icons, the site's own icons, Google favicon,
  generic theme icon.
- `webapp-remove` to remove a web app or list installed ones.
- `install.sh` / `uninstall.sh`, bats test suite, CI.

### Security

- Strict validation of names and URLs to prevent desktop entry injection.
- Downloads restricted to http(s), with time and size limits; icons checked by content.

[Unreleased]: https://github.com/andyraitra/webapp-kit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/andyraitra/webapp-kit/releases/tag/v0.1.0
