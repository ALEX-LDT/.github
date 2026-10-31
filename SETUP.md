# ALEX-LDT setup checklist

The settings of the ALEX-LDT GitHub organisation, kept by hand on GitHub Free. Each setting lists its expected value, the API field [`scripts/audit.sh`](scripts/audit.sh) checks, and how to set it.

**Changing a setting:** open a pull request that changes this file (and the expected values at the top of `audit.sh`, if affected). Once it is merged, an owner applies the change by hand. The next audit run confirms it.

**Audit:** an owner runs `scripts/audit.sh` monthly, alongside the monthly Update, and after every settings change. It is read-only. Any FAIL needs fixing; WARN lines need a look.

## Organisation

Settings → Member privileges, Authentication security and Actions → General, or `gh api -X PATCH orgs/ALEX-LDT -F <field>=<value>`.

| Setting | Expected | API field |
| --- | --- | --- |
| Two-factor authentication required | on (web UI only: Authentication security) | `two_factor_requirement_enabled` |
| Base repository permission | Read | `default_repository_permission` |
| Repository creation by members | off, public and private (members request repositories in [requests](https://github.com/ALEX-LDT/requests)) | `members_can_create_repositories`, `members_can_create_public_repositories`, `members_can_create_private_repositories` |
| Repository visibility change | owners only | `members_can_change_repo_visibility` |
| Repository deletion and transfer | owners only | `members_can_delete_repositories` |
| Issue deletion | owners only | `members_can_delete_issues` |
| Forking of private repositories | off | `members_can_fork_private_repositories` |
| Team creation by members | on (decision on hold) | `members_can_create_teams` |

## Actions

| Setting | Expected | Set with |
| --- | --- | --- |
| Allowed actions | GitHub-owned, plus `ldt4ssc/*` (the template's validation workflow) and actions listed here individually | `gh api -X PUT orgs/ALEX-LDT/actions/permissions -f enabled_repositories=all -f allowed_actions=selected`, then `gh api -X PUT orgs/ALEX-LDT/actions/permissions/selected-actions -F github_owned_allowed=true -F verified_allowed=false -f 'patterns_allowed[]=ldt4ssc/*'` |
| Default workflow token | read-only; workflows cannot approve pull requests | `gh api -X PUT orgs/ALEX-LDT/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false` |

## Owners and teams

**Owners:** two from FVH, acting for the Coordinator (City of Helsinki). Owners from the City of Helsinki and Prague may be added later. Expected owners are listed in `EXPECTED_OWNERS` in `audit.sh`.

**Joining:** people join through a [New Member](https://github.com/ALEX-LDT/requests/issues/new?template=04-new-member.yml) request. The owner invites them into their teams; everyone needs two-factor authentication before accepting.

| Team | Parent | Access |
| --- | --- | --- |
| `maintainers` | none | Maintain on `.github`, `requests` and `ldt4ssc-alex`; code owners for `pilot.yaml`, `README.md` and `.github/` in `ldt4ssc-alex` |
| `consortium` | none | none; everyone in ALEX, for mentions |
| `pilot-editors` | `consortium` | Write on `ldt4ssc-alex`; members agreed by the consortium |
| `city-of-helsinki`, `forum-virium-helsinki`, `ipr-praha`, `operator-ict`, `ics-cas`, `nls-fgi`, `visions` | `consortium` | Admin on their own development repositories, Write where they collaborate; the partner's lead is team maintainer |

All teams are visible to members ("closed") and have a description. Repository access for partner teams is managed by each repository's admins.

## Repositories

Every repository:

| Setting | Expected | Set with |
| --- | --- | --- |
| Merge methods | squash only | `gh repo edit ALEX-LDT/<repo> --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false` |
| Delete branch after merge | on | `gh repo edit ALEX-LDT/<repo> --delete-branch-on-merge` |
| Outside collaborators | none, unless agreed. Not enforceable on Free: any repository admin can invite them | `audit.sh` lists them per repository |
| Commits on the default branch | through merged pull requests only | `audit.sh` lists commits from the last 30 days that did not come from one |

Public repositories also need:

| Setting | Expected | Set with |
| --- | --- | --- |
| Approved for publication | listed in `APPROVED_PUBLIC_REPOS` in `audit.sh`, after a [Publish Repository](https://github.com/ALEX-LDT/requests/issues/new?template=02-publish-repository.yml) request | pull request to `audit.sh` |
| Secret scanning and push protection | on | `gh api -X PATCH repos/ALEX-LDT/<repo> -f 'security_and_analysis[secret_scanning][status]=enabled' -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'` |
| Private vulnerability reporting | on | `gh api -X PUT repos/ALEX-LDT/<repo>/private-vulnerability-reporting` |
| Dependabot alerts | on | `gh api -X PUT repos/ALEX-LDT/<repo>/vulnerability-alerts` |
| Default-branch ruleset | block deletion and force push, linear history, pull request with 1 approval, approvals dismissed on new commits, squash only | `gh api -X POST repos/ALEX-LDT/<repo>/rulesets --input <ruleset.json>`, as for `.github` (ruleset "Protect main") |
| Ruleset bypass | none. During setup, owners may bypass so README-only commits can go straight to `main`; remove the bypass when setup ends | `bypass_actors` in the ruleset |

`ldt4ssc-alex` (Phase 5) also needs the required `lint` check in its ruleset, code owner review, topics `ldt4ssc`, `local-digital-twin` and `ws3`, wiki off, and registration with the LDT4SSC Helpdesk.

## Go-public gate

Making a private repository public follows an approved Publish Repository request with a recorded consortium decision. The owner then:

1. Scans the full history for secrets: `gitleaks git --log-opts="--all" .`
2. Changes the visibility: `gh repo edit ALEX-LDT/<repo> --visibility public --accept-visibility-change-consequences`
3. Turns on the public-repository settings above and applies the ruleset.
4. Adds the repository to `APPROVED_PUBLIC_REPOS` in `audit.sh` and runs the audit.
5. Links the repository from the `ldt4ssc-alex` README.

## Not enforceable on GitHub Free

| Rule | Why | Instead |
| --- | --- | --- |
| Only owners invite outside collaborators | Enterprise Cloud only | `audit.sh` lists outside collaborators |
| Members create private repositories only | Enterprise Cloud only | Owners create repositories on request |
| Pull requests reviewed by another partner | GitHub can require an approval, not who gives it | Pull request template checklist; reviewers |
| Rulesets on private repositories | Public repositories only on Free | `audit.sh` lists direct commits |
