# ADR-001: Create shared bioml-commons repository

**Status:** Accepted
**Date:** 2026-04-13
**Decision makers:** antomicblitz

## Problem

OralBiome-AMP and UTI-project share the same core toolchain (Boltz-2, AlphaFold3, OpenMM, Vina, GNINA, RDKit, Vast.ai cloud GPU) but maintain independent, duplicated implementations of shared infrastructure. As of 2026-04-13:

- **12 of 29 open issues** across both repos concern shared infrastructure
- UTI-project #9 asks about Boltz-2 IP/licensing — a cross-project concern
- UTI-project #8 asks where to put things that don't belong in a single project
- OralBiome-AMP #89 has a missing `cloud/base.py` that should be a shared abstraction
- OralBiome-AMP #48 requires backporting SSH fixes between two orchestrators — a DRY violation
- UTI-project #1/#2/#3 need MD worker extraction — the extracted module is reusable across projects
- Both projects deploy to Vast.ai with duplicated scripts (Python in OralBiome, bash in UTI)

## Decision

Create `repos/lambda/bioml-commons/` as a shared repository for cross-cutting research, documentation, and (later) shared code.

### What goes in bioml-commons

- License & IP research (model/tool audits, commercial use flags)
- Architecture decision records (ADRs)
- Shared cloud infrastructure (Vast.ai runner, R2 sink, SSH deploy, GPU estimator)
- Shared Docker images (Boltz-2, OpenMM)
- Shared MD modules (worker, equilibration, clash detection, trajectory analysis)
- CI templates
- Operational guides (Vast.ai deployment, GPU pitfalls)

### What stays in project repos

- Pipeline code (targets, scoring, formulation, docking configs)
- Domain-specific data (AMP libraries, compound libraries, target registries)
- Project-specific governance (AGENTS.md domain rules, CONTRIBUTING.md)

## Alternatives considered

1. **Monorepo merge** — combine OralBiome-AMP and UTI-project into one repo. Rejected: the projects have different lifecycles, contributors, and CI requirements.
2. **Git submodules** — add bioml-commons as a submodule in both projects. Possible in future; not needed for Phase 1 (docs only).
3. **Python package** — publish shared code as a pip-installable package. Possible for Phase 2+; premature for Phase 1.
4. **Do nothing** — keep duplicating. Rejected: 12 open issues about shared infra, and the problem grows with each new project.

## Migration plan

| Phase | Scope | Closes |
|-------|-------|--------|
| 1 (now) | License audit + this ADR | UTI #9, UTI #8 |
| 2 | Cloud infra (`base.py`, vastai runner, R2, SSH deploy) | OralBiome #89, #48, #47, #46 |
| 3 | GPU estimator + Docker images | OralBiome #85, #49 |
| 4 | MD worker + clash detection + trajectory analysis | UTI #1, #2, #3; OralBiome #6, #75 |
| 5 | CI templates | UTI #11 |

Each phase is a separate PR to bioml-commons + update PRs to consumer repos.

## Consequences

- Both projects gain a shared reference for licensing and compliance
- New projects under Lambda Biolab start with shared infra instead of copying from OralBiome-AMP
- Shared code changes propagate to all consumers (version pinning recommended once code is added)
- Adds one more repo to maintain — acceptable given the duplication it eliminates
