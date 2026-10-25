# Contributing

Thanks for helping! Bug reports, browser/desktop compatibility notes and pull
requests are all welcome.

## Development setup

The linters and test runner are pinned in `mise.toml`:

```bash
mise install        # shellcheck, shfmt, bats
make check          # lint + tests
make fmt            # format shell files
```

Without mise, install `shellcheck`, `shfmt`, `bats` and `desktop-file-utils` from
your distribution. The tests never touch the network or your real desktop: they run
with a temporary `$HOME` and stubbed `curl` and browsers.

## Pull requests

- Open an issue first for larger changes.
- Every behaviour change comes with tests, edge cases included.
- Keep `make check` green; do not disable shellcheck rules to make it pass.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
  `docs:`, `test:`, `ci:`, ...).
- **Commits must be signed** (GPG or SSH). `main` only accepts signed commits through
  pull requests. To sign with your SSH key:

  ```bash
  git config gpg.format ssh
  git config user.signingkey ~/.ssh/id_ed25519.pub
  git config commit.gpgsign true
  ```

  and add the key to GitHub as a *signing key*
  ([docs](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)).
- Update `CHANGELOG.md` under *Unreleased*.

By contributing, you agree that your contributions are licensed under the MIT license
and that you follow the [Code of Conduct](CODE_OF_CONDUCT.md).
