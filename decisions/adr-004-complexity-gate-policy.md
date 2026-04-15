# ADR-004: Complexity gate policy — complexipy ≤15 enforced in pre-commit

**Status:** Accepted
**Date:** 2026-04-15
**Decision makers:** antomicblitz, qte77
**Relates to:** [ADR-002](adr-002-adopt-biolab-runners.md), [ADR-003](adr-003-adopt-vastai-gpu-runner.md)

## Problem

By early April 2026, OralBiome-AMP's `src/oral_amp/main.py` had grown to ~4,500 lines containing dozens of CLI commands with cognitive complexity up to 100 in a single function. The bloat had two root causes:

1. **No mechanical gate.** `ruff`'s `C901` mccabe rule was configured but marked `# TODO` in `pyproject.toml` because ~80 functions exceeded the threshold at the time of configuration. It was never enforced.
2. **No cultural norm.** New CLI commands were added inline to `main.py` because "that's where the others live," and each new command usually added a few branches to an existing helper.

The refactor finished on 2026-04-15 split `main.py` into eleven `src/oral_amp/cli/*.py` modules and reduced every function's cognitive complexity to ≤15. Without a mechanical gate, this state will not hold — within weeks, the next feature addition will push some function over 15 again, and without enforcement it will stay there.

qte77's PR #95 set the threshold at 15 (complexipy's cognitive complexity, not mccabe's cyclomatic complexity) but did not wire the gate into pre-commit because at the time of that PR, many functions were still over the limit. On 2026-04-15, the gate was wired into `.pre-commit-config.yaml` for `src/oral_amp/cli/` only.

## Decision

All Lambda Biolab consumer projects enforce **cognitive complexity ≤15** via `complexipy` as a pre-commit hook, on a directory scope that starts narrow and widens over time.

### Threshold: 15 (cognitive, not cyclomatic)

Cognitive complexity (complexipy) penalizes nested branches more heavily than flat sequences of `if` statements, which aligns with how readable code actually scales. Cyclomatic complexity (`C901`) treats every branch equally and produces false positives on simple dispatch tables.

15 is the threshold qte77 chose. It is strict enough that extracting helpers is usually the right response, and loose enough that typical domain code (parser with a few branches, config builder with conditional fields) passes without contortion.

### Scope: start narrow, widen ratchet-style

- **Phase 1 (now):** gate enforces complexity on the directory currently under the threshold. For OralBiome-AMP this is `src/oral_amp/cli/`. For UTI-project this is whatever directory is clean when the gate is adopted — could be nothing initially.
- **Phase 2+:** pick 1–3 files adjacent to the gate scope, bring them under 15, and expand the gate to include them. Repeat every few sessions.
- **Never** widen the gate past what is currently passing. A gate that fails immediately on commit is a gate that gets disabled.

### Enforcement mechanism

```yaml
# .pre-commit-config.yaml
- id: complexipy-cli
  name: complexipy (cognitive ≤15)
  entry: uv run complexipy src/<SCOPE>/ --max-complexity-allowed 15
  language: system
  pass_filenames: false
  types: [python]
```

The gate runs locally on every commit and in CI. A commit that introduces a >15 function is blocked at commit time, not at review time, so the feedback loop is immediate.

### What to do when you hit the gate

1. **Extract helpers.** Most >15 functions are doing three things; pull the inner loops and branch blocks into named helpers. This is what the 2026-04-15 refactor did for 45+ functions with no behavioral change.
2. **Rethink the signature.** If you can't cleanly extract, the function is probably mixing concerns. Split into two public functions.
3. **Raise the threshold** only if the function is fundamentally irreducible *and* domain-critical *and* better documented than it would be after decomposition. This should be rare and is a code-review discussion, not a default.

`# noqa` / `// complexipy: ignore` comments are not acceptable. There is no exception annotation in `complexipy`; bypassing the gate requires explicit approval and a comment in the PR.

## Alternatives considered

1. **Cyclomatic complexity (mccabe `C901`) instead of cognitive.** Rejected: flat branch tables hit the mccabe limit easily without being hard to read. The 2026-04-15 refactor specifically hit cases where mccabe complained but the code was clearer than any extraction would make it.
2. **Threshold of 10 or 20.** 10 is too strict (pure dispatch/builder functions start failing), 20 is loose enough that meaningful structural problems slip through. 15 is the Schelling point qte77 arrived at after working on his own refactor PRs and it has proven workable.
3. **Whole-src gate from day one.** Rejected (already tried): OralBiome-AMP has 87 functions outside cli/ that exceed 15, including the 360/93 cloud orchestrators. A gate that fails 87 times is a gate that gets disabled. Ratchet-style widening is the only strategy that survives contact with existing debt.
4. **CI-only, not pre-commit.** Rejected: the feedback loop must be local. A complexity failure discovered in CI is one that the developer has already context-switched away from.
5. **Reviewer discipline instead of a mechanical gate.** Rejected (already tried): this is how OralBiome-AMP got to complexity 360 in the first place. Human review does not consistently catch complexity drift, especially under deadline pressure.

## Migration plan

Per consumer project:

1. **Measure current state.** Run `complexipy src/ --max-complexity-allowed 15` and note which directories have zero failures.
2. **Wire the gate** on the cleanest directory. Commit the `.pre-commit-config.yaml` change.
3. **Ratchet.** Every time a directory-under-the-gate function is touched, check adjacent files. When a neighbouring file comes under 15, add it to the gate scope in a small dedicated commit.
4. **Track non-cli debt.** Keep a running list of the highest-complexity non-cli functions. For OralBiome-AMP as of 2026-04-15, the worst five are `Boltz2CloudBatch._run_locked_inner` (360), `OpenMMCloudBatch._run_locked` (93), `predict_binding_site` (74), `evolve` (73), `poll_and_deploy` (66). The first two are addressed by ADR-003 (deleted, not refactored).

## Consequences

- **Positive:** The refactor done on 2026-04-15 cannot silently regress. Future bloat is mechanically prevented inside the gated scope.
- **Positive:** New contributors learn the complexity ceiling from a failing commit, not a code review comment. The standard is explicit.
- **Positive:** Ratchet-style widening makes the non-cli debt addressable as a series of small commits instead of one unaffordable refactor.
- **Negative:** Some legitimate code patterns (e.g., a large dispatch table) require extraction that feels ceremonial. Mitigation: dispatch tables are usually better as module-level dicts anyway, which complexipy does not count.
- **Negative:** The ratchet requires discipline to actually widen. If nobody ever expands the gate past the initial scope, the debt outside the scope never gets paid.

## Anti-drift rule

If a consumer project suppresses the `complexipy` hook globally, adds a `# noqa: complexipy` pattern via monkey-patching, or pins `complexipy` at a version without the `--max-complexity-allowed` flag to bypass the gate, that is a violation of this ADR. The fix is always: decompose the offending function, or open a PR to this ADR proposing a threshold change with concrete examples.
