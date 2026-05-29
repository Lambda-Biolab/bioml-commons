# ADR-007: Shared GHA workflow governance

**Status:** Accepted
**Date:** 2026-05-29
**Decision makers:** Antonio

## Context

The Lambda Biolab org publishes reusable GitHub Actions workflows across
repos. These shared workflows require consumers to reference them at a
specific version. Without an explicit governance rule, three problems
compound:

1. **Version drift.** Consumers using `@main` get silently broken by
   upstream changes. This is the same failure mode as the ADR-005 anti-drift
   problem for shared Python code.

2. **Bump fan-out.** Each shared workflow release requires updating N
   consumer YAMLs. With no script, this drifts in practice.

3. **SHA-pin compliance.** The recent CodeQL workflow incident
   (`bioml-commons#16`) demonstrated the cost: Dependabot bumped
   `actions/checkout` and `github/codeql-action` from full-length SHA pins
   back to tag pins, causing the weekly cron to fail silently. The fix
   required a manual SHA-pin re-application. The same drift mechanism
   applies to references to `Lambda-Biolab/gha-*` reusable workflows.

## Decision

All consumer references to `Lambda-Biolab/gha-*` reusable workflows MUST be
pinned to a full-length commit SHA, not a release tag or branch name.

Each consumer repo ships a `scripts/bump-shared-actions.sh` that updates
every pinned reference in one pass.

### SHA-pinning contract

In any consumer workflow YAML:

```yaml
jobs:
  eval:
    uses: Lambda-Biolab/gha-rxiv-paper-eval/.github/workflows/eval-papers.yaml@abc123def456abc123def456abc123def456abc1
    with:
      eval_repo: Lambda-Biolab/gha-rxiv-paper-eval
      eval_ref: abc123def456abc123def456abc123def456abc1
      ...
```

- `uses:` always pinned to a full-length commit SHA, never `@main` or a
  semver tag.
- When the reusable workflow accepts paired `<name>_repo` + `<name>_ref`
  inputs, the consumer MUST align them to the same SHA.
- Third-party actions (`actions/checkout`, `astral-sh/setup-uv`, etc.) MUST
  also be SHA-pinned per org policy.

### Per-consumer bump script

Each consumer ships `scripts/bump-shared-actions.sh`:

```bash
#!/usr/bin/env bash
# Update all Lambda-Biolab/gha-* references in .github/workflows/ to a new SHA.
# Usage: scripts/bump-shared-actions.sh <action-name> <new-sha>
#   e.g. scripts/bump-shared-actions.sh gha-rxiv-paper-eval abc123def456abc123def456abc123def456abc1

set -euo pipefail
action="${1:?action name (e.g. gha-rxiv-paper-eval)}"
new_sha="${2:?new SHA}"

find .github/workflows -name '*.yml' -o -name '*.yaml' | while read -r f; do
  sed -E -i \
    -e "s|(Lambda-Biolab/${action}/[^@]+@)[a-f0-9]{40}|\1${new_sha}|g" \
    -e "s|(eval_ref:\s*)[a-f0-9]{40}|\1${new_sha}|g" \
    "$f"
done

echo "✓ bumped ${action} to ${new_sha} across .github/workflows/"
```

Run on each release of a shared workflow, commit, open PR, merge once CI
passes.

### Why a per-consumer script (not a central bumper)

Rejected a centralised bumper that posts cross-repo PRs from
`bioml-commons` because:

1. **Repo-local control.** Each consumer may legitimately stay one release
   behind. A centralised bumper forces a coordination dance.
2. **No new infra dependency.** A simple shell script in each repo is less
   to maintain than a bumper bot.
3. **Maps cleanly to scaffolding.** A future repo-scaffolding routine can
   stamp the script into every new repo.

## Release discipline for shared workflows

Repos publishing `Lambda-Biolab/gha-*` workflows MUST:

1. Record the SHA for each release in `CHANGELOG.md` so consumers can copy
   the correct pin.
2. Document breaking changes in `CHANGELOG.md` with explicit "Consumer
   action required" notes.
3. For reusable workflows that take `<name>_repo` + `<name>_ref` inputs:
   ensure these stay required and explicit. Auto-derivation from
   `github.workflow_ref` breaks cross-repo callers.
4. Keep the previous SHA buildable for at least one release cycle to give
   consumers time to bump.

## Anti-drift rule

If a consumer workflow references a shared `Lambda-Biolab/gha-*` workflow
with `@main`, `@<branch>`, or a semver tag, that is a violation of this
ADR. The fix is always: reference the SHA corresponding to the latest
stable release, update the consumer, and re-run.

Verified by a CI lint step (future enhancement):

```bash
grep -rE 'Lambda-Biolab/gha-[^@]+@(main|master|v[0-9]+)' .github/workflows/ \
  && { echo "::error::shared GHA reference not pinned to a full-length SHA"; exit 1; } \
  || echo "✓ all shared GHA references pinned to SHAs"
```

## Consequences

- **Positive:** Consumer breakage from upstream changes drops to zero —
  they break on intentional bump, not on upstream release.
- **Positive:** Bumping is a one-line invocation per consumer.
- **Positive:** The CodeQL drift incident cannot recur for shared
  workflows — Dependabot's action-bumper may suggest tag pins, but the CI
  lint rule catches them.
- **Negative:** N repos × M scripts file copies is some duplication.
  Mitigated: the script is small and identical across consumers.
- **Negative:** Slight friction when testing against an unreleased SHA of
  a shared workflow. Mitigated: point the pin at the target SHA
  temporarily; update before merge.
- **Negative:** Dependabot will periodically open PRs suggesting tag pins
  for SHA-pinned `Lambda-Biolab/gha-*` references. Resolution: close as
  "won't fix" per ADR-007, keeping the SHA pin.
