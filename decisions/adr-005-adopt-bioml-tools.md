# ADR-005: Adopt bioml-tools as the shared computational toolkit

**Status:** Accepted
**Date:** 2026-04-16
**Decision makers:** antomicblitz
**Relates to:** [ADR-001](adr-001-shared-repo.md) (shared repo rationale), [ADR-002](adr-002-adopt-biolab-runners.md) (local execution), [ADR-003](adr-003-adopt-vastai-gpu-runner.md) (cloud orchestration), [ADR-004](adr-004-complexity-gate-policy.md) (complexity gates)

## Problem

OralBiome-AMP contains ~13,000 lines of domain-agnostic computational infrastructure — peptide property calculations, PDB structure handling, docking wrappers, selectivity analysis, and MD trajectory analysis — that is duplicated or will need to be duplicated in UTI-project and future pipelines. This code has no project-specific coupling (no target registry, no scoring weights, no formulation logic) but currently lives inside `oral_amp`, making reuse impossible without importing the entire project.

Specific pain points:

- UTI-project needs physicochemical filters, Vina docking, geometry validation, and trajectory analysis — all of which exist in OralBiome-AMP but cannot be imported
- `oral_amp.structure.binding_site_predictor` (1,558 lines) wraps P2Rank, PeSTo, AlphaFill, conservation scoring, and residue clustering — general tools locked inside a project-specific package
- `oral_amp.docking.geometry_validator` (787 lines) and `oral_amp.docking.vina_runner` (652 lines) are pure wrappers around external tools with zero project coupling
- Peptide property calculations (`physicochemical.py`, `stability_predictor.py`, `hemolysis_predictor.py`, `admet_scorer.py`) are stateless pure functions trapped behind a project-specific import path
- `oral_amp.md` contains generic OpenMM system building, trajectory analysis, interface metrics, and topology reconstruction — reusable by any MD pipeline

The existing extraction pattern (ADR-002: `biolab-runners`, ADR-003: `vastai-gpu-runner`) addresses execution engines and cloud orchestration. This ADR addresses the remaining computational layer.

## Decision

All Lambda Biolab consumer projects adopt `bioml-tools` as their shared computational toolkit for peptide properties, structure handling, docking, selectivity analysis, and MD analysis. Project code MUST NOT re-implement these computations; it MUST import from `bioml_tools`.

### Package structure

A single repository (`Lambda-Biolab/bioml-tools`) with five subpackages:

```
bioml_tools/
  peptide/      # Physicochemical, stability, hemolysis, ADMET, operators, generation, patents
  structure/    # PDB fetching, pocket detection, structure prep, conservation, binding site prediction
  docking/      # Grid generation, Vina runner, pose parsing, geometry validation, counterscreen
  selectivity/  # FoldX runner, interface mapping
  md/           # System building, checkpoint handling, trajectory analysis, topology, MMPBSA
```

### Why one repo, not three

Early design considered separate `peptide-tools`, `biostructure-tools`, and `docking-tools` repos. Rejected because:

1. **Dependency chain overhead.** `docking-tools` would depend on both `biostructure-tools` (geometry, structure prep) and `peptide-tools` (physicochemical filters). Every version bump requires coordinated releases across three repos. For a 2-person org, this governance cost exceeds the benefit.
2. **No independent consumers.** Nobody will install just peptide properties without also needing structure handling. Our real consumers (OralBiome-AMP, UTI-project) need the full stack.
3. **3x CI, ADRs, changelogs, pre-commit configs.** One well-gated repo is less maintenance than three small ones.
4. **Internal refactoring friction.** Moving a function between subpackages is a single-repo PR, not a cross-repo migration.

Optional dependency groups gate heavy installs:
```toml
[project.optional-dependencies]
peptide = ["biopython>=1.83", "rdkit>=2024.3"]
structure = ["biopython>=1.83", "gemmi==0.6.5"]
docking = ["numpy>=1.26", "meeko>=0.7.1"]
md = ["mdanalysis>=2.7", "numpy>=1.26", "openmm>=8.5.0"]
all = ["bioml-tools[peptide,structure,docking,selectivity,md]"]
```

### Scope boundary rule

`bioml-tools` contains **stateless, pure-computation modules only**. If a module needs network I/O, filesystem state, GPU orchestration, or project-specific configuration, it belongs in a consumer project or in `biolab-runners`/`vastai-gpu-runner`.

### Interface contract

- Functions accept data (sequences, PDB paths, coordinates) as parameters — never look up project registries internally
- No `oral_amp`, `uti_project`, or other consumer-project imports
- Optional external tools (FoldX, fpocket, P2Rank, Vina-GPU) degrade gracefully with clear error messages
- Type annotations on all public functions (pyright basic mode)

### What stays in consumer projects

- Target registries and configuration (project-specific pathogen/target data)
- Scoring weights and composite formulas (project IP)
- Formulation, combination, and synergy logic
- Cloud orchestration and state management
- CLI dispatch and command registration
- Fitness evaluators and evolution loops (project-specific GA configuration)
- Glue code that couples extractable modules with non-extractable ones (e.g., `counterscreen_rescore.py` couples docking with `prediction.boltz2_runner`)

## Alternatives considered

1. **Three separate repos** (`peptide-tools`, `biostructure-tools`, `docking-tools`). Rejected: 3x governance overhead, dependency chain coordination, no independent consumer base. See "Why one repo" above.
2. **Two repos** (merge `biostructure-tools` + `docking-tools`, keep `peptide-tools` separate). Rejected: still 2x governance for marginal separation benefit. Peptide properties are always used alongside structure/docking in our pipelines.
3. **Expand `biolab-runners` to include all computational modules**. Rejected: `biolab-runners` has a clear scope (local GPU execution of Boltz-2 and OpenMM). Adding peptide properties and docking would violate its single responsibility.
4. **Keep everything in `oral_amp` and have UTI-project depend on it**. Rejected: forces UTI-project to install oral-pathogen-specific code, creates false coupling, makes independent versioning impossible.

## Migration plan

Migration uses a shim-based approach that preserves all existing import paths during transition:

1. **Scaffold** `bioml-tools` repo with governance files, CI, pre-commit, complexipy <=15.
2. **Phase 1 — zero-coupling extraction.** Copy 24 files with no `oral_amp` imports to bioml-tools. Replace originals with shim files that re-export from `bioml_tools`. All 1,371 tests pass through shims.
3. **Phase 2 — coupled extraction.** Decouple ~5 modules from `oral_amp.targets.registry` via parameter injection (push `get_target()` calls up to callers). Extract ~10 additional files. Split `binding_site_predictor.py` (1,558 lines) into public API + 5 private submodules.
4. **Cleanup.** Replace shim imports with direct `bioml_tools` imports across OralBiome-AMP. Delete shim files.
5. **UTI-project adoption.** Add `bioml-tools[all]` as dependency, replace duplicated implementations.

## Consequences

- **Positive:** ~13,000 lines of reusable infrastructure become available to all Lambda Biolab projects without importing project-specific code.
- **Positive:** UTI-project can share physicochemical filters, Vina docking, geometry validation, and trajectory analysis immediately after adoption.
- **Positive:** Future pipelines inherit battle-tested computational tools; barrier to new project setup drops significantly.
- **Positive:** `binding_site_predictor.py` gets split from 1,558 lines into 6 focused modules — improving maintainability.
- **Negative:** ~34 shim files exist during transition, adding temporary indirection. Mitigated: cleanup phase removes all shims.
- **Negative:** Debugging stack traces traverse two packages (`bioml_tools` + consumer). Mitigated: functions are stateless and self-contained; errors are local.
- **Negative:** One more package to version and release. Mitigated: single repo with one CI, one changelog, one version — less overhead than alternatives.

## Anti-drift rule

If a consumer project reimplements a function that exists in `bioml-tools` (physicochemical calculation, geometry validation, trajectory analysis, etc.), that is a violation of this ADR. The fix is always: upstream the feature to `bioml-tools`, release, bump the consumer.

## Quality gates

- Cognitive complexity <=15 from day one (no ratchet — all code is extracted clean or refactored during extraction)
- pyright basic mode, `reportMissingImports = false` for optional dependencies
- ruff with full rule set (E, F, I, UP, D, N, S, B, A, C4, SIM, TCH, ARG, C90)
- Google-style docstrings
- pytest + Hypothesis, coverage floor established after Phase 1
- Zero `oral_amp` or `uti_project` imports in source (CI-enforced grep check)
