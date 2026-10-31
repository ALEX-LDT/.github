#!/usr/bin/env bash
# Read-only audit of the ALEX-LDT GitHub organisation against SETUP.md.
#
# Usage: scripts/audit.sh
# Needs: gh (signed in as an organisation owner, scopes read:org and repo) and jq.
# Makes GET requests only. Prints PASS / WARN / FAIL / INFO lines and exits 1 if any check fails.
#
# Change the expected values below through a pull request, together with SETUP.md.

ORG=ALEX-LDT
EXPECTED_OWNERS="TatuE laurigates"
APPROVED_PUBLIC_REPOS=".github ldt4ssc-alex"
REQUIRED_REPOS=".github requests ldt4ssc-alex"
ACTIONS_PATTERNS='["ldt4ssc/*"]'
TOP_LEVEL_TEAMS="maintainers consortium"
CONSORTIUM_CHILD_TEAMS="pilot-editors city-of-helsinki forum-virium-helsinki ipr-praha operator-ict ics-cas nls-fgi visions"
LOOKBACK_DAYS=30

set -uo pipefail

failures=0
warnings=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf 'INFO  %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }
contains() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

# expect <description> <actual> <expected>
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (is '$2', expected '$3')"; fi
}

since=$(jq -rn --argjson d "$LOOKBACK_DAYS" 'now - $d * 86400 | todate')

command -v gh >/dev/null || { echo "gh is not installed" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is not installed" >&2; exit 2; }
org_json=$(gh api "orgs/$ORG") || { echo "cannot read orgs/$ORG; sign in with gh auth login" >&2; exit 2; }
org_field() { printf '%s' "$org_json" | jq -r "$1"; }

printf 'ALEX-LDT audit, %s (lookback %s days)\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "$LOOKBACK_DAYS"

section "Organisation settings"
expect "Two-factor authentication required" "$(org_field .two_factor_requirement_enabled)" true
expect "Base repository permission is read" "$(org_field .default_repository_permission)" read
expect "Members cannot create repositories" "$(org_field .members_can_create_repositories)" false
expect "Members cannot create public repositories" "$(org_field .members_can_create_public_repositories)" false
expect "Members cannot create private repositories" "$(org_field .members_can_create_private_repositories)" false
expect "Only owners change repository visibility" "$(org_field .members_can_change_repo_visibility)" false
expect "Only owners delete or transfer repositories" "$(org_field .members_can_delete_repositories)" false
expect "Only owners delete issues" "$(org_field .members_can_delete_issues)" false
expect "Forking of private repositories is off" "$(org_field .members_can_fork_private_repositories)" false
info "Members can create teams: $(org_field .members_can_create_teams) (decision on hold)"
info "Restricting outside-collaborator invitations needs Enterprise Cloud; see the per-repository lists below"

section "Actions"
actions=$(gh api "orgs/$ORG/actions/permissions")
expect "Actions limited to selected actions" "$(printf '%s' "$actions" | jq -r .allowed_actions)" selected
selected=$(gh api "orgs/$ORG/actions/permissions/selected-actions" 2>/dev/null || echo '{}')
expect "GitHub-owned actions allowed" "$(printf '%s' "$selected" | jq -r .github_owned_allowed)" true
expect "Verified-creator actions not allowed" "$(printf '%s' "$selected" | jq -r .verified_allowed)" false
expect "Allowed action patterns" "$(printf '%s' "$selected" | jq -c '.patterns_allowed // [] | sort')" "$(printf '%s' "$ACTIONS_PATTERNS" | jq -c sort)"
workflow=$(gh api "orgs/$ORG/actions/permissions/workflow")
expect "Default workflow token is read-only" "$(printf '%s' "$workflow" | jq -r .default_workflow_permissions)" read
expect "Workflows cannot approve pull requests" "$(printf '%s' "$workflow" | jq -r .can_approve_pull_request_reviews)" false

section "Owners and invitations"
owners=$(gh api --paginate "orgs/$ORG/members?role=admin" --jq '.[].login' | tr '\n' ' ')
pending=$(gh api --paginate "orgs/$ORG/invitations" --jq '.[] | "\(.login // .email):\(.role)"' | tr '\n' ' ')
for o in $owners; do
  if contains "$EXPECTED_OWNERS" "$o"; then pass "Owner $o is expected"; else fail "Owner $o is not in EXPECTED_OWNERS"; fi
done
for o in $EXPECTED_OWNERS; do
  contains "$owners" "$o" && continue
  if contains "$pending" "$o:admin"; then warn "Expected owner $o has a pending invitation"; else fail "Expected owner $o is not an owner"; fi
done
[ -n "$pending" ] && info "Pending invitations: $pending"

section "Teams"
teams=$(gh api --paginate "orgs/$ORG/teams" --jq '.[] | "\(.slug)|\(.parent.slug // "-")|\(.privacy)|\(.description // "")"')
team_line() { printf '%s\n' "$teams" | grep "^$1|"; }
check_team() { # check_team <slug> <expected parent or ->
  line=$(team_line "$1")
  if [ -z "$line" ]; then fail "Team $1 is missing"; return; fi
  parent=$(printf '%s' "$line" | cut -d'|' -f2)
  privacy=$(printf '%s' "$line" | cut -d'|' -f3)
  description=$(printf '%s' "$line" | cut -d'|' -f4-)
  expect "Team $1 parent" "$parent" "$2"
  expect "Team $1 is visible to members" "$privacy" closed
  if [ -n "$description" ]; then pass "Team $1 has a description"; else fail "Team $1 has no description"; fi
}
for t in $TOP_LEVEL_TEAMS; do check_team "$t" -; done
for t in $CONSORTIUM_CHILD_TEAMS; do check_team "$t" consortium; done
for t in $(printf '%s\n' "$teams" | cut -d'|' -f1); do
  contains "$TOP_LEVEL_TEAMS $CONSORTIUM_CHILD_TEAMS" "$t" || warn "Team $t is not in SETUP.md"
done

section "Repositories"
repos=$(gh api --paginate "orgs/$ORG/repos?type=all" --jq '.[] | "\(.name)|\(.visibility)|\(.default_branch)|\(.archived)"')
for r in $REQUIRED_REPOS; do
  printf '%s\n' "$repos" | grep -q "^$r|" || warn "Repository $r does not exist yet"
done

while IFS='|' read -r name visibility branch archived; do
  [ -z "$name" ] && continue
  section "Repository $name ($visibility)"
  [ "$archived" = true ] && { info "Archived; skipped"; continue; }
  repo=$(gh api "repos/$ORG/$name")
  rf() { printf '%s' "$repo" | jq -r "$1"; }

  if [ "$visibility" = public ] && ! contains "$APPROVED_PUBLIC_REPOS" "$name"; then
    fail "Public but not in APPROVED_PUBLIC_REPOS: published without the Publish Repository process?"
  fi

  expect "Squash merge allowed" "$(rf .allow_squash_merge)" true
  expect "Merge commits disabled" "$(rf .allow_merge_commit)" false
  expect "Rebase merge disabled" "$(rf .allow_rebase_merge)" false
  expect "Branches deleted after merge" "$(rf .delete_branch_on_merge)" true

  if [ "$visibility" = public ]; then
    expect "Secret scanning" "$(rf .security_and_analysis.secret_scanning.status)" enabled
    expect "Push protection" "$(rf .security_and_analysis.secret_scanning_push_protection.status)" enabled
    expect "Private vulnerability reporting" "$(gh api "repos/$ORG/$name/private-vulnerability-reporting" --jq .enabled 2>/dev/null || echo unknown)" true
    if gh api "repos/$ORG/$name/vulnerability-alerts" >/dev/null 2>&1; then pass "Dependabot alerts"; else fail "Dependabot alerts are off"; fi

    rules=$(gh api "repos/$ORG/$name/rules/branches/$branch" 2>/dev/null || echo '[]')
    has_rule() { printf '%s' "$rules" | jq -e --arg t "$1" 'any(.[]; .type == $t)' >/dev/null; }
    for t in deletion non_fast_forward required_linear_history pull_request; do
      if has_rule "$t"; then pass "Rule on $branch: $t"; else fail "Rule on $branch missing: $t"; fi
    done
    approvals=$(printf '%s' "$rules" | jq -r '[.[] | select(.type == "pull_request") | .parameters.required_approving_review_count] | max // 0')
    if [ "$approvals" -ge 1 ]; then pass "Pull requests need $approvals approval(s)"; else fail "Pull requests need no approval"; fi

    bypass=$(gh api "repos/$ORG/$name/rulesets" --jq '.[].id' | while read -r id; do
      gh api "repos/$ORG/$name/rulesets/$id" --jq '.bypass_actors[] | "\(.actor_type):\(.bypass_mode)"'
    done | sort -u | tr '\n' ' ')
    if [ -n "$bypass" ]; then warn "Ruleset bypass allowed: $bypass(remove when setup ends)"; else pass "No ruleset bypass"; fi
    used=$(gh api "repos/$ORG/$name/rulesets/rule-suites?time_period=month&rule_suite_result=bypass" \
      --jq '.[] | "\(.pushed_at[0:10]) \(.actor_name) \(.ref | sub("refs/heads/"; ""))"' 2>/dev/null)
    if [ -n "$used" ]; then while read -r line; do info "Bypass used: $line"; done <<< "$used"; fi
  fi

  outside=$(gh api --paginate "repos/$ORG/$name/collaborators?affiliation=outside" --jq '.[] | "\(.login):\(.role_name)"' 2>/dev/null | tr '\n' ' ')
  if [ -n "$outside" ]; then warn "Outside collaborators: $outside"; else pass "No outside collaborators"; fi

  direct=$(gh api "repos/$ORG/$name/commits?sha=$branch&since=$since&per_page=100" --jq '.[].sha' 2>/dev/null | while read -r sha; do
    merged=$(gh api "repos/$ORG/$name/commits/$sha/pulls" --jq '[.[] | select(.merged_at != null)] | length' 2>/dev/null || echo 0)
    [ "$merged" = 0 ] && gh api "repos/$ORG/$name/commits/$sha" --jq '"\(.sha[0:7]) \(.commit.author.date[0:10]) \(.commit.message | split("\n")[0])"'
  done)
  if [ -n "$direct" ]; then
    while read -r line; do warn "Commit on $branch without a merged pull request: $line"; done <<< "$direct"
  else
    pass "Every commit on $branch in the last $LOOKBACK_DAYS days came from a merged pull request"
  fi
done <<< "$repos"

section "Summary"
printf '%s failure(s), %s warning(s)\n' "$failures" "$warnings"
[ "$failures" -eq 0 ]
