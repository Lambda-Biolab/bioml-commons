# ADR-002: Adopt biolab-runners as the local execution layer

**Status:** Accepted
**Date:** 2026-04-15
**Decision makers:** antomicblitz
**Supersedes:** Phase 4 of [ADR-001](adr-001-shared-repo.md) (partially — the local runner extraction, not the cloud-worker extraction)

## Problem

Both OralBiome-AMP and UTI-project need to run Boltz-2 structure prediction and OpenMM molecular dynamics locally (for development, smoke tests, and single-candidate runs). Today, both projects maintain their own copies of this code:

- `OralBiome-AMP/src/oral_amp/prediction/boltz2_runner.py` — local Boltz-2 driver with MSA cache lookup, pocket constraints, dry-run mode, quality gating
- `OralBiome-AMP/src/oral_amp/md/openmm_runner.py` — local OpenMM driver with 3-stage equilibration, production NPT, checkpointing, SIGTERM handling, 5 ns early-abort gate
- UTI-project has analogous but independently maintained drivers

The two projects share the same physics (force field choices, equilibration protocol, SIGTERM cleanup logic) but they're not sharing the same code. When OralBiome-AMP fixed the equilibration displacement bug (2026-04-04), UTI-project did not automatically inherit the fix.

`biolab-runners` ([github.com/Lambda-Biolab/biolab-runners](https://github.com/Lambda-Biolab/biolab-runners)) was extracted from OralBiome-AMP's local-runner code as a standalone, pip-installable package with:

- `Boltz2Runner` — local GPU structure prediction with quality gating, MSA caching, pocket constraints, dry-run mode
- `OpenMMRunner` — full MD pipeline: system building, 3-stage equilibration, production NPT, checkpointing, early abort, SIGTERM handling
- Config-driven dataclasses (no magic strings)
- Structured result objects (not raw dicts)
- Full type annotations (pyright-clean)
- Python logging (no print statements)

As of 2026-04-15, OralBiome-AMP does not yet import from `biolab_runners`. The duplication is still fully live.

## Decision

All Lambda Biolab consumer projects adopt `biolab-runners` as their local execution layer for Boltz-2 and OpenMM. Project code MUST NOT re-implement local runner logic; it MUST either use `biolab-runners` directly or submit a PR upstream if a needed feature is missing.

### Interface contract

- Consumer projects import `Boltz2Runner` / `OpenMMRunner` and pass a project-specific config dataclass.
- Consumer projects provide thin adapters for domain concerns (target registries, scoring thresholds, verdict semantics) — these live in the consumer repo, not upstream.
- Upstream fixes (equilibration protocol, force field defaults, SIGTERM handling) reach all consumers via a `biolab-runners` version bump.

### What stays in consumer projects

- Target configs (residue numbering, pocket constraints, chain selection) — domain data, not execution logic
- Scoring and verdict thresholds — project-specific policy
- CLI wiring and user-facing commands
- Pipeline state tracking and leaderboards

## Alternatives considered

1. **Keep duplicating.** Rejected: the equilibration-displacement incident proved that fixes don't propagate across projects when the code is duplicated. Every future physics fix has the same risk.
2. **Git submodule instead of pip package.** Rejected: pip is the standard Python mechanism, version pinning is explicit in `pyproject.toml`, and submodules add a git operation to every clone without corresponding benefit.
3. **Monorepo (merge biolab-runners into bioml-commons).** Rejected: `biolab-runners` has its own release cadence, smoke tests, and public pip distribution. Merging would couple its lifecycle to governance docs it has no reason to share.
4. **Extract a thinner wrapper (utils only, not the runner classes).** Rejected: the runner classes are exactly the reusable unit — the 3-stage equilibration protocol, checkpoint/resume logic, and early-abort gating are non-trivial and error-prone to re-implement.

## Migration plan

Per consumer project, in order:

1. **Add dependency.** `uv add 'biolab-runners>=X.Y'` (with the `[boltz2]` extra if the project runs Boltz-2). All Lambda Biolab projects use `uv` as the package manager; `uv pip` is a compatibility shim for pip-migration flows and is not used in greenfield workflows.
2. **Adapter layer.** Create a `consumer/local_runners.py` that constructs `biolab_runners` configs from the project's domain objects (targets, peptides, thresholds).
3. **Smoke test before deletion.** Run a single prediction and a single MD job through the new adapter on a known-good candidate; diff the outputs against the archived result.
4. **Delete duplicated code.** Remove the consumer's `prediction/boltz2_runner.py` and `md/openmm_runner.py`. Update all imports.
5. **Verify tests.** Full suite must pass. Any test that used internal symbols of the old runner files must move to `biolab-runners` or be rewritten to target the adapter.
6. **Pin version.** After adoption, pin the `biolab-runners` version in `pyproject.toml` to prevent silent upgrades (`uv lock` captures the exact resolution in `uv.lock`).

OralBiome-AMP is the first adopter (largest duplication surface, biolab-runners was extracted from it). UTI-project follows once the OralBiome-AMP migration has shipped and been exercised in a real batch.

## Consequences

- **Positive:** one fix, many consumers. The equilibration incident cannot repeat silently.
- **Positive:** new consumer projects start with a working local runner instead of copying 2,000+ lines.
- **Positive:** `biolab-runners` gets real-world exercise beyond its extraction repo, which will surface abstraction leaks early.
- **Negative:** cross-repo coordination cost. A fix in `biolab-runners` requires a release + consumer bumps.
- **Negative:** consumer test suites must be written against the public `biolab-runners` API, not internal symbols. Tests that relied on monkey-patching internal functions must be rewritten.
- **Negative:** domain-specific features that would have been a one-line addition locally now require either an upstream PR or a subclass — more friction for experimentation.

## Anti-drift rule

If a consumer project is caught re-implementing `Boltz2Runner` or `OpenMMRunner` functionality inside its own tree, that is a violation of this ADR. The fix is always: upstream the feature to `biolab-runners`, release, bump the consumer.
