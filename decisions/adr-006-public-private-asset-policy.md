# ADR-006: Public vs private asset policy

**Status:** Accepted
**Date:** 2026-05-27
**Decision makers:** antomicblitz, qte77
**Relates to:** [ADR-001](adr-001-shared-repo.md) (shared repo rationale), [ADR-005](adr-005-adopt-bioml-tools.md) (bioml-tools anti-drift pattern)

## Problem

Lambda Biolab is approaching open-source release of substantial portions of its agent + drug-discovery infrastructure. The default-public model (everything in `Lambda-Biolab/*` is public unless flagged otherwise) is appropriate for engineering hygiene, tooling, and infrastructure code. It is **not** appropriate for two categories of asset:

1. **Legally exposed components.** Some retrieval modules in the research agents target full-text sources where the redistribution status is ambiguous or unfavourable. The engineering is real, but shipping it under a public Lambda-Biolab repo creates reputational + potential legal exposure.

2. **High-defensibility curated assets.** Hand-curated holdouts and human-expert ground-truth labels took expert time that competitors cannot reproduce by reading source. Code converges across labs; curated evaluation data does not. Publishing these would surrender the lab's strongest competitive differentiator.

The two categories need different physical homes than the default-public org. Without an org-wide policy, the boundary is ad-hoc and prone to drift.

## Decision

All Lambda Biolab assets are classified into one of three tiers. The tier determines the repo where the asset lives.

### Tier A — Private

Closed, lab-only repos under the `Lambda-Biolab/bioml-private-*` naming convention. Reserved for:

- Retrieval integrations with ambiguous or unfavourable redistribution status
- Hand-curated evaluation data (target holdouts, human-labelled ground truth, curated benchmark sets)
- Future categories with the same risk/moat profile

Two private repos are established now:

| Repo | Purpose | Currently holds |
|---|---|---|
| [`Lambda-Biolab/bioml-private-retrieval`](https://github.com/Lambda-Biolab/bioml-private-retrieval) | Retrieval modules with redistribution constraints | (see private repo) |
| [`Lambda-Biolab/bioml-private-evaldata`](https://github.com/Lambda-Biolab/bioml-private-evaldata) | Curated evaluation data | Hand-curated holdouts, human-expert ground-truth labels |

Per-repo access: push for `antomicblitz` + `qte77`; wider expansion decided per-repo when needed.

### Tier B — Public, with signal value

Open-source. The default tier for engineering work that is publishable. Includes:

- Pipeline architecture, prompts, AGENTS.md, working conventions
- Tooling code (retrieval cascades for OA sources, scoring, evaluation harnesses)
- Methodology docs
- Auto-generated holdouts (OpenTargets-derived, etc.) — derivable from public data
- Workflow YAML, GHA consumer configs

Publishing has direct value (recruiting, community, reference design); keeping private has zero offsetting benefit because the moat lives in the Tier A data, not in the code that consumes it.

### Tier C — Public, shared infrastructure

Existing public repos under Lambda-Biolab — `bioml-tools`, `biolab-runners`, `vastai-gpu-runner`, `bioml-commons`, `bioml-diagrams`, `gha-rxiv-feed-action`, `gha-rxiv-paper-eval`. No change from current state.

## Consumer integration contract

Public consumer agents (e.g. `deep-research-agent`, future agent repos) integrate with the private packages via **optional import / configurable path**:

```python
# Python package (bioml-private-retrieval)
try:
    from bioml_private_retrieval import retrieve_a, retrieve_b
except ImportError:
    retrieve_a = None
    retrieve_b = None

# Pure data repo (bioml-private-evaldata)
PRIVATE_EVALDATA_DIR = Path(
    os.environ.get(
        "BIOML_PRIVATE_EVALDATA_DIR",
        str(Path.home() / "projects" / "bioml-private-evaldata"),
    )
)
```

Functions guard with `is None` checks; harness scripts guard with `.exists()` checks. When the private package or data is absent, the relevant code paths gracefully degrade — they do not error.

This pattern works in two directions:
- **For public CI** on consumer repos: tests that strictly require private data are marked `@pytest.mark.skipif(not _DATA_PRESENT, ...)`. The public test suite passes on a clean clone.
- **For external contributors**: they can clone a public repo, run `make validate`, and ship contributions without ever needing private-repo access.

## Anti-drift rule

Three-part rule, all CI-enforced:

1. **No private filenames in public repos.** Each public agent repo runs a `scripts/check_private_assets.sh` first-step in CI that fails the build if any canonical private filename appears outside `docs/`. The script enumerates the exact filenames inline (Python modules from `bioml-private-retrieval`, curated YAMLs and ground-truth JSONs from `bioml-private-evaldata`). Override via `ALLOW_PRIVATE_ASSETS=1` with PR-description justification.

2. **No reimplementing the private modules in public code.** Same rule as ADR-005's bioml-tools anti-drift rule — if you find yourself reimplementing a `bioml-private-retrieval` module inside a public agent, that is a policy violation; the fix is to add the missing feature to the private package, release, bump the consumer.

3. **No commits of `~/research-state/` contents into any repo.** This directory is the agent's working dir for Tier A artefacts; per-repo gitignore is insufficient (the dir lives outside any one repo), so a global gitignore line + the safety-net script catch it.

## Calibrated-prompt re-review trigger

Per the policy lock (D4): every agent repo's `agents/*.md` calibrated prompts stay **Tier B** by default. Re-review for possible B → A migration when **(a) 6 months elapsed since last review, OR (b) any single prompt has had ≥5 substantive edits since last review** — whichever fires first. A recurring GitHub issue per agent repo tracks the schedule. Same trigger applies to topic-filter prompts in shared GHA workflows.

## Migration history

The five execution phases ran in series on 2026-05-27 starting from `deep-research-agent` as the proving-ground consumer. All landed via squash-merged PRs:

| Phase | Scope | PR |
|---|---|---|
| 1 | Policy proposal + decisions lock | `Lambda-Biolab/deep-research-agent#70`, `#71` |
| 2 | Extract `bioml-private-retrieval` | `Lambda-Biolab/deep-research-agent#73` |
| 3 | Extract `bioml-private-evaldata` (holdouts + ground-truth labels) | `Lambda-Biolab/deep-research-agent#74` |
| 4 | CI safety net + `docs/research-state.md` | `Lambda-Biolab/deep-research-agent#75` |
| 5 | GHA weekly-rxiv-digest adoption on deep-research-agent | `Lambda-Biolab/deep-research-agent#72` |

The full per-asset inventory and decision detail for the initial migration live in [`deep-research-agent/docs/public-private-asset-policy.md`](https://github.com/Lambda-Biolab/deep-research-agent/blob/main/docs/public-private-asset-policy.md). That doc is the historical record for the first consumer; this ADR is the org-wide rule going forward.

## Alternatives considered

1. **Keep everything public.** Rejected: legal exposure on the retrieval modules with redistribution constraints, and gives away curated holdouts that are the actual competitive moat.
2. **Make the entire `deep-research-agent` private.** Rejected: gives up community signal value for ~2,000 lines of public-good infrastructure (OA retrieval tiers 1-4, AGENTS.md, architecture docs, scoring harness) to protect ~336 lines of legally-exposed code and ~54KB of holdout data. Wrong cost/benefit.
3. **Use `*-internal` or `*-private` suffixes without the `bioml-` prefix.** Rejected: breaks the existing `bioml-*` org convention (`bioml-tools`, `bioml-commons`, `bioml-diagrams`, `bioml-runners`).
4. **Three-tier classification at the file level rather than the repo level.** Rejected: GitHub's access model is per-repo; per-file gating means LFS or sidecar files which adds operational complexity without solving the moat problem.

## Consequences

- **Positive:** Legal exposure isolated. The modules with redistribution constraints no longer ship under a public Lambda-Biolab repo.
- **Positive:** Curated holdouts and ground-truth labels remain proprietary while methodology stays public — anyone can read how we curate, no one can copy what we curated.
- **Positive:** Public agent repos remain installable and runnable end-to-end on OA paths. External contributors get a working dev loop without private-repo access.
- **Positive:** Future agent repos inherit the pattern automatically once the `scaffolding-agent-repo` skill ships with the templates baked in.
- **Negative:** Two more repos to govern (collaborator lists, CI, release cadence).
- **Negative:** Developer setup requires cloning two private repos to `~/projects/` for the local full-stack experience. Mitigated by env-var override and graceful skip on absence.
- **Negative:** Per-agent re-review cadence (D4 trigger) adds a recurring chore. Mitigated: trigger-based, not pure calendar — usually a no-op.

## Quality gates

Public agent repos consuming this policy MUST:

- Wrap the `bioml-private-retrieval` import in `try/except ImportError` with `is None` guards at call sites.
- Load `bioml-private-evaldata` data via the `BIOML_PRIVATE_EVALDATA_DIR` env var with a sensible default and `.exists()` guards.
- Run the `check_private_assets.sh` safety net as the first CI step on every PR.
- Mark tests that strictly require private data with `@pytest.mark.skipif`.
- Document any per-agent private-asset additions in the agent's own ADR or policy doc; the org-wide rule is this file.

Private repos under `bioml-private-*` MUST:

- Be created with restricted access (push for current maintainers only; expand explicitly).
- Use the standard quality gates (ruff + pyright + complexipy ≤ 15 for Python; yamllint + JSON schema validation for data).
- Mirror the public-repo CI patterns (SHA-pinned actions per org policy).
- Reference this ADR in their README's "Why this repo is private" section.
