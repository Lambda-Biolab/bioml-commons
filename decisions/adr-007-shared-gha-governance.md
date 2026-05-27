# ADR-007: Shared GitHub Actions workflow governance

**Status:** Accepted
**Date:** 2026-05-27
**Decision makers:** antomicblitz, qte77
**Relates to:** [ADR-005](adr-005-adopt-bioml-tools.md) (anti-drift via tag-pinning pattern), [ADR-006](adr-006-public-private-asset-policy.md) (Phase 5 of public/private policy)

## Problem

The Lambda Biolab org publishes reusable GitHub Actions workflows for cross-repo automation. Currently:

- [`Lambda-Biolab/gha-rxiv-paper-eval`](https://github.com/Lambda-Biolab/gha-rxiv-paper-eval) — weekly preprint relevance filter, consumed by each agent repo with a per-agent topic prompt.
- [`Lambda-Biolab/gha-rxiv-feed-action`](https://github.com/Lambda-Biolab/gha-rxiv-feed-action) — the upstream producer that emits the weekly CSV consumed by the above.

More are expected (release automation, model evaluation cron jobs, doc publishing) as agent repos multiply. Without an explicit governance rule for how consumers reference these shared workflows, three problems compound:

1. **Version drift.** Consumers using `@main` get silently broken by upstream changes (e.g. the v0.2.0 `eval-papers.yaml` auto-derivation that broke all cross-repo callers — required v0.2.1 to re-introduce explicit `eval_repo` + `eval_ref` inputs).
2. **Bump fan-out.** Each new release of a shared workflow requires updating N consumer YAMLs. With no script, this is N hand-edits per release; with N=5 agents, that is ~30 minutes of mechanical work that drifts in practice.
3. **No single source of truth** for the "shared GHA upgrade procedure", so each consumer's bumping pattern diverges.

Same shape as the [ADR-005](adr-005-adopt-bioml-tools.md) anti-drift problem for shared Python code — solved there by tag-pinning + a per-consumer policy. This ADR applies the same pattern to shared workflows.

## Decision

All consumer references to `Lambda-Biolab/gha-*` reusable workflows MUST be pinned to a release tag (never `@main`, never a moving branch). Each consumer repo ships a `scripts/bump-shared-actions.sh` that updates every pinned reference in one pass.

### Tag-pinning contract

In any consumer workflow YAML:

```yaml
jobs:
  eval:
    uses: Lambda-Biolab/gha-rxiv-paper-eval/.github/workflows/eval-papers.yaml@v0.2.2
    with:
      eval_repo: Lambda-Biolab/gha-rxiv-paper-eval
      eval_ref: v0.2.2   # MUST match the @<tag> above
      ...
```

- `uses:` always pinned to a `vX.Y.Z` release tag, never `@main` or a SHA.
- When the reusable workflow accepts paired `<name>_repo` + `<name>_ref` inputs (as `gha-rxiv-paper-eval` does), the consumer MUST set them explicitly to match the `uses:` pin. The auto-derivation pattern (using `github.workflow_ref`) does not work for cross-repo callers and was removed in `gha-rxiv-paper-eval@v0.2.1`.
- Third-party actions (`actions/checkout`, `astral-sh/setup-uv`, etc.) MUST be pinned to a full commit SHA per Lambda-Biolab org policy.

### Per-consumer bump script

Each consumer ships `scripts/bump-shared-actions.sh`:

```bash
#!/usr/bin/env bash
# Update all Lambda-Biolab/gha-* references in .github/workflows/ to a new tag.
# Usage: scripts/bump-shared-actions.sh <action-name> <new-tag>
#   e.g. scripts/bump-shared-actions.sh gha-rxiv-paper-eval v0.2.3

set -euo pipefail
action="${1:?action name (e.g. gha-rxiv-paper-eval)}"
new_tag="${2:?new tag (e.g. v0.2.3)}"

# Update `uses:` lines + matching `_ref:` inputs in one pass.
find .github/workflows -name '*.yml' -o -name '*.yaml' | while read -r f; do
  sed -E -i \
    -e "s|(Lambda-Biolab/${action}/[^@]+@)v[0-9]+\.[0-9]+\.[0-9]+|\1${new_tag}|g" \
    -e "s|(eval_ref:\s*)v[0-9]+\.[0-9]+\.[0-9]+|\1${new_tag}|g" \
    "$f"
done

echo "✓ bumped ${action} to ${new_tag} across .github/workflows/"
```

Run on each release of a shared workflow, commit, open PR, merge once CI passes.

### Why a per-consumer script (not a central bumper)

Considered (and rejected) a centralised bumper that posts cross-repo PRs from `bioml-commons`. Rejected because:

1. **Repo-local control.** Each consumer may legitimately stay one release behind (e.g. waiting for a breaking-change post-mortem). A centralised bumper forces a coordination dance.
2. **No new infra dependency.** A 10-line shell script in each repo is less to maintain than a bumper bot.
3. **Maps cleanly to scaffolding.** The future `scaffolding-agent-repo` skill stamps the script into every new agent repo for free.

## Release discipline for shared workflows

Repos publishing `Lambda-Biolab/gha-*` workflows MUST:

1. Tag every release (`vMAJOR.MINOR.PATCH`). Never expect consumers to track `main`.
2. Document breaking changes in `CHANGELOG.md` with explicit "Consumer action required" notes.
3. For reusable workflows that take `<name>_repo` + `<name>_ref` inputs (cross-repo SHA alignment): ensure these stay required + explicit. Auto-derivation from `github.workflow_ref` breaks cross-repo callers.
4. Keep the previous minor branch buildable for at least one release cycle to give consumers time to bump.

## Anti-drift rule

If a consumer workflow references a shared `Lambda-Biolab/gha-*` workflow with `@main`, `@<branch>`, or any non-tag ref, that is a violation of this ADR. The fix is always: tag the latest stable version of the shared workflow, update the consumer to `@<tag>`, and re-run.

Verified by a CI lint step in consumer repos (future enhancement):

```bash
grep -rE 'Lambda-Biolab/gha-[^@]+@(main|master|[a-f0-9]{7,40})' .github/workflows/ \
  && { echo "::error::shared GHA reference not pinned to a release tag"; exit 1; } \
  || echo "✓ all shared GHA references pinned to tags"
```

## Quality gates

Consumer repos:

- All `Lambda-Biolab/gha-*` references in `.github/workflows/` pinned to a release tag.
- Where applicable, paired `<name>_repo` + `<name>_ref` inputs match the `uses:` pin.
- A `scripts/bump-shared-actions.sh` (or equivalent) present and executable.
- The `scaffolding-agent-repo` skill (when it ships) stamps the script + the pin convention into every new repo.

Publisher repos (`gha-*`):

- Releases tagged `vMAJOR.MINOR.PATCH` semver.
- `CHANGELOG.md` with "Consumer action required" notes on breaking changes.
- Cross-repo caller inputs (`<name>_repo` + `<name>_ref`) kept explicit and required.

## Alternatives considered

1. **Centralised bumper bot in `bioml-commons`** that opens cross-repo PRs. Rejected: maintenance overhead, removes per-consumer release-timing control, no clear ownership story.
2. **Dependabot for GitHub Actions on shared workflows.** Dependabot doesn't natively understand the `eval_repo` + `eval_ref` cross-repo pairing — it bumps the `uses:` line but not the matching input, breaking the consumer. Rejected for shared reusable workflows; still recommended for third-party SHA-pinned actions.
3. **`@main` everywhere with manual coordination.** Rejected: this is the status quo's failure mode, and the v0.2.0 breakage already proved the cost.

## Consequences

- **Positive:** Consumer breakage from upstream changes drops to zero — they break on bump, not on cron schedule.
- **Positive:** Bumping is a one-line invocation per consumer (10 minutes for N=5 agents instead of 30 minutes of hand-edits).
- **Positive:** Pairs cleanly with [ADR-006 Phase 5](adr-006-public-private-asset-policy.md) — every agent repo that adopts the GHA weekly-digest also inherits this governance.
- **Positive:** Future shared workflows (release automation, eval cron, etc.) inherit the pattern.
- **Negative:** N repos × M scripts file copies is some duplication. Mitigated: the script is small, identical across consumers, and stamped by the scaffolding skill.
- **Negative:** Slight friction when needing to test against an unreleased `main` of a shared workflow. Mitigated: temporarily set the pin to a SHA + the override flag for the test PR; do not merge until a tagged release ships.
