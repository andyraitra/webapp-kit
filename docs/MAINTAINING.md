# Maintaining

## Repository protection

`scripts/configure-github.sh` applies these settings (idempotent, needs repo admin):

| Setting | Value |
| --- | --- |
| `main` ruleset (`.github/rulesets/main.json`) | Changes only through pull requests, signed commits required, linear history, CI job `check` must pass on an up-to-date branch, conversations resolved, no force push, no deletion |
| Merge methods | Squash only (GitHub signs the squash commit), branches deleted after merge |
| Release tags (`.github/rulesets/tags.json`) | `v*` tags can only be created, moved or deleted by repository admins |
| Security | Secret scanning + push protection, Dependabot alerts and security updates, private vulnerability reporting |
| Actions | Read-only `GITHUB_TOKEN` by default, only GitHub-owned actions and `jdx/mise-action`, pinned by full commit SHA |
| Features | Wiki and Projects disabled |

Pull requests need 0 approvals so a solo maintainer can merge; raise
`required_approving_review_count` in `main.json` once there are other maintainers.

## Signing setup (once per machine)

```bash
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname) signing"

git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true
git config tag.gpgsign true
```

## Releasing

1. Move the *Unreleased* entries in `CHANGELOG.md` to a new version section and bump
   `VERSION` in `bin/webapp-install` and `bin/webapp-remove` (plus the tests), in a PR.
2. After merging, tag the merge commit with a signed tag and publish the release:

   ```bash
   git switch main && git pull --ff-only
   git tag -s v0.2.0 -m "v0.2.0"
   git push origin v0.2.0
   gh release create v0.2.0 --verify-tag --notes-from-tag
   ```
