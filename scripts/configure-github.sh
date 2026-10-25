#!/usr/bin/env bash
# Apply the repository settings and rulesets described in docs/MAINTAINING.md.
# Idempotent: safe to re-run after editing .github/rulesets/*.json.
#
# Usage: scripts/configure-github.sh [owner/repo]   (needs gh, repo admin)
set -euo pipefail

for dep in gh jq; do
  command -v "$dep" >/dev/null 2>&1 || {
    printf 'error: %s is required\n' "$dep" >&2
    exit 1
  }
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

step() {
  printf '==> %s\n' "$1"
}

step "Repository settings (squash merge only, delete merged branches, no wiki/projects)"
gh api -X PATCH "repos/$REPO" --silent \
  -F has_wiki=false -F has_projects=false \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true -F allow_update_branch=true \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY

step "Secret scanning and push protection"
gh api -X PATCH "repos/$REPO" --silent --input - <<'EOF'
{"security_and_analysis": {
  "secret_scanning": {"status": "enabled"},
  "secret_scanning_push_protection": {"status": "enabled"}
}}
EOF

step "Dependabot alerts and security updates"
gh api -X PUT "repos/$REPO/vulnerability-alerts" --silent
gh api -X PUT "repos/$REPO/automated-security-fixes" --silent

step "Private vulnerability reporting"
gh api -X PUT "repos/$REPO/private-vulnerability-reporting" --silent

step "Actions: read-only token, GitHub-owned actions + jdx/mise-action, pinned by SHA"
gh api -X PUT "repos/$REPO/actions/permissions/workflow" --silent \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
gh api -X PUT "repos/$REPO/actions/permissions" --silent \
  -F enabled=true -f allowed_actions=selected -F sha_pinning_required=true
gh api -X PUT "repos/$REPO/actions/permissions/selected-actions" --silent --input - <<'EOF'
{"github_owned_allowed": true, "verified_allowed": false, "patterns_allowed": ["jdx/mise-action@*"]}
EOF

for file in "$ROOT"/.github/rulesets/*.json; do
  name=$(jq -r .name "$file")
  id=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  if [[ -n "$id" ]]; then
    step "Update ruleset: $name"
    gh api -X PUT "repos/$REPO/rulesets/$id" --silent --input "$file"
  else
    step "Create ruleset: $name"
    gh api -X POST "repos/$REPO/rulesets" --silent --input "$file"
  fi
done

step "Done: https://github.com/$REPO/settings/rules"
