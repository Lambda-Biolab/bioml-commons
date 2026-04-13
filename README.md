# bioml-commons

Shared research, infrastructure, and tooling for Lambda Biolab's computational drug discovery pipelines.

## Purpose

Multiple projects ([OralBiome-AMP](https://github.com/Lambda-Biolab/OralBiome-AMP), [UTI-project](https://github.com/Lambda-Biolab/UTI-project)) share the same core toolchain: Boltz-2, AlphaFold3, OpenMM, AutoDock Vina, GNINA, RDKit, and Vast.ai cloud GPU infrastructure. This repo is the single source of truth for cross-cutting concerns.

## What belongs here

- **License & IP research** — model/tool license audits, commercial use flags
- **Architecture decisions** — ADRs for shared tooling choices
- **Shared infrastructure** (planned) — cloud GPU orchestration, Docker images, MD protocols, CI templates

## What does NOT belong here

- Project-specific pipeline code (targets, scoring, formulation)
- Domain-specific data (AMP libraries, compound libraries)
- Anything derivable from reading the project's own code or git history

## Structure

```
bioml-commons/
├── licenses/                  # License audits and compliance
│   └── model-tool-comparison.md
└── decisions/                 # Architecture decision records
    └── adr-001-shared-repo.md
```

## Consumer projects

| Project | Repo | Shared tools |
|---------|------|-------------|
| OralBiome-AMP | [Lambda-Biolab/OralBiome-AMP](https://github.com/Lambda-Biolab/OralBiome-AMP) | Boltz-2, AF3, OpenMM, Vina-GPU, Vast.ai, R2 |
| UTI-project | [Lambda-Biolab/UTI-project](https://github.com/Lambda-Biolab/UTI-project) | Boltz-2, AF3, OpenMM, Vina, GNINA, Vast.ai |
