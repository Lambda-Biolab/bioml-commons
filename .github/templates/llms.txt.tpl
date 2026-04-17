# bioml-commons

> Shared research, infrastructure, and tooling for Lambda Biolab's computational drug discovery pipelines.

Multiple projects (OralBiome-AMP, UTI-project) share the same core toolchain:
Boltz-2, AlphaFold3, OpenMM, AutoDock Vina, GNINA, RDKit, and Vast.ai cloud GPU
infrastructure. This repo is the single source of truth for cross-cutting concerns.

## Documentation

- [README](${BLOB}/README.md): Project overview, structure, and consumer projects
- [Model & Tool License Comparison](${BLOB}/licenses/model-tool-comparison.md): Comprehensive license audit for structure prediction models, docking tools, MD engines, force fields, cheminformatics, and infrastructure
- [ADR-001: Create shared bioml-commons repository](${BLOB}/decisions/adr-001-shared-repo.md): Decision record for creating this shared repository across Lambda Biolab projects
