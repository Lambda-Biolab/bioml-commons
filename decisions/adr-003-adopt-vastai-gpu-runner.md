# ADR-003: Adopt vastai-gpu-runner as the cloud orchestration layer

**Status:** Accepted
**Date:** 2026-04-15
**Decision makers:** antomicblitz
**Supersedes:** Phase 2 of [ADR-001](adr-001-shared-repo.md) (the cloud-infrastructure extraction)
**Relates to:** [ADR-002](adr-002-adopt-biolab-runners.md) (local execution layer — complementary concern)

## Problem

Cloud GPU batch orchestration (deploy N Vast.ai instances, shard work across them, poll for completion, handle preemption, clean up) is the most complex subsystem in OralBiome-AMP and the source of most cloud-related bugs:

- `Boltz2CloudBatch._run_locked_inner` — cognitive complexity **360** (single function)
- `OpenMMCloudBatch._run_locked` — cognitive complexity **93**
- Multiple open issues about divergent behavior between the two orchestrators (OralBiome-AMP #48, #49, #50, #84)
- Sibling-file rule (`AGENTS.md`) exists specifically because fixes to one orchestrator routinely miss the other
- UTI-project needs cloud orchestration too, currently implemented as bash scripts that duplicate a subset of the Python logic

The `vastai-gpu-runner` package ([github.com/Lambda-Biolab/vastai-gpu-runner](https://github.com/Lambda-Biolab/vastai-gpu-runner)) was extracted from OralBiome-AMP to address this. It provides:

- `BaseWorker` — template-method worker pattern (R2 connectivity gate, R2 upload, self-destruct via Vast.ai REST API, PID file, completion markers)
- `BatchOrchestrator` — deploy/poll/cleanup lifecycle with shard recovery, checkpoint resume, instance destroy-and-replace
- R2Sink — configurable Cloudflare R2 sync (bucket/prefix constructor params, no hardcoded defaults)
- Vast.ai API lifecycle (search, deploy, poll, destroy, error classification)

As of 2026-04-15, adoption is **partial**: OralBiome-AMP's `boltz2_worker.py` and `openmm_worker.py` subclass `BaseWorker`, but the orchestrators (`Boltz2CloudBatch`, `OpenMMCloudBatch`) are still the hand-rolled versions. This is the "Phase 3 continued" item from the 2026-04-12 session handoff — never started.

## Decision

All Lambda Biolab consumer projects adopt `vastai-gpu-runner` as their cloud orchestration layer for Vast.ai-based GPU batches. Project code MUST NOT re-implement the deploy/poll/cleanup loop; it MUST subclass `BaseWorker` (for workers) and `BatchOrchestrator` (for orchestrators).

### Interface contract

- Workers subclass `BaseWorker` and implement domain-specific `run_job()` — nothing else. Connectivity gates, upload, self-destruct, PID/completion markers are inherited.
- Orchestrators subclass `BatchOrchestrator` and implement domain-specific job serialization, result collection, and failure classification. Deploy/poll/destroy lifecycle is inherited.
- R2Sink is instantiated with consumer-specific bucket/prefix; the base class has no OralBiome-AMP or UTI-project defaults.
- Vast.ai image allowlists are constructor parameters, not module constants.

### What stays in consumer projects

- Job payload construction (what does a "unit of work" mean for this project)
- Result parsing and verdict assignment (domain-specific)
- Batch state files and progress tracking (per-project output schemas)
- Cost budgets and GPU-type preferences (project policy)

## Alternatives considered

1. **Keep the hand-rolled orchestrators, just refactor them under complexipy ≤15.** Rejected: we'd be splitting a complexity-360 function into helpers that still live in OralBiome-AMP, solving the complexity number but not the duplication with UTI-project and not the sibling-drift problem. The refactor is work we'd have to throw away when we eventually migrate.
2. **Use SkyPilot or another existing orchestration framework.** Rejected previously (see session history 2026-04-01): Vast.ai's API semantics, spot-instance preemption patterns, and R2 checkpoint requirements don't map cleanly to SkyPilot abstractions. The extraction effort that produced `vastai-gpu-runner` was itself the response to that evaluation.
3. **Merge `vastai-gpu-runner` into `biolab-runners` or `bioml-commons`.** Rejected: `vastai-gpu-runner` is provider-specific (Vast.ai) and its lifecycle is coupled to Vast.ai API changes, which are unrelated to local execution (biolab-runners) or governance docs (bioml-commons). Keeping the boundaries clean is worth one more package.
4. **Support multiple cloud providers in one package.** Deferred: if Lambda Biolab ever deploys to RunPod or Lambda Cloud, the right move is probably a second package (`runpod-gpu-runner`) with a shared interface, not one package with branching logic.

## Migration plan

The worker half is already done. This ADR governs the orchestrator half:

1. **Branch.** Create `phase3-orchestrator-migration` off `gen-2` (OralBiome-AMP) to isolate the risk.
2. **Smoke test baseline.** Run the existing `Boltz2CloudBatch` and `OpenMMCloudBatch` smoke tests, archive outputs as the reference.
3. **Boltz-2 orchestrator.** Subclass `BatchOrchestrator`, port job payload construction + result collection, delete `_run_locked_inner`. Verify against smoke-test reference.
4. **OpenMM orchestrator.** Same pattern. Verify against smoke-test reference.
5. **Delete shims.** The compatibility shims from the worker migration (`cloud/base.py`, `cloud/vastai_runner.py`, `cloud/r2_sink.py`) can be removed once all imports resolve directly to `vastai_gpu_runner`.
6. **Siblings rule retirement.** The AGENTS.md sibling table row for "Boltz-2 cloud orchestrator | OpenMM cloud orchestrator | lifecycle, checkpoint, resume, cleanup" is deleted — the shared abstraction enforces this structurally and no longer needs a manual anti-drift rule.
7. **UTI-project adoption.** Once OralBiome-AMP has run a real batch through the new orchestrator, replace UTI-project's bash deploy scripts with a `BatchOrchestrator` subclass. This ADR is the license to make that change.

## Consequences

- **Positive:** `Boltz2CloudBatch._run_locked_inner` (360) and `OpenMMCloudBatch._run_locked` (93) cease to exist — the codebase's two worst complexity hotspots are *deleted*, not refactored.
- **Positive:** Sibling drift is structurally prevented. Fixes to deploy/poll/cleanup land in one place and apply to all consumers.
- **Positive:** UTI-project gets Python-based cloud orchestration without re-deriving it from scratch.
- **Positive:** New consumer projects inherit a battle-tested orchestrator; the barrier to spinning up a new pipeline drops from "implement deploy/poll/cleanup" to "subclass BatchOrchestrator."
- **Negative:** Migration carries real risk — these orchestrators spend GPU budget. Mitigation: dedicated branch, smoke tests before merge, do it as a single focused effort (not rolled into unrelated refactors).
- **Negative:** Debugging a failed cloud batch now requires knowledge of two codebases (consumer adapter + `vastai-gpu-runner` base class). Mitigation: stack traces remain per-worker, and the base class is small and well-tested.

## Anti-drift rule

If a consumer project reimplements deploy/poll/cleanup logic, or adds a "temporary" copy of `BatchOrchestrator` inside its own tree, that is a violation of this ADR. The fix is always: upstream the feature to `vastai-gpu-runner`, release, bump the consumer.

## Related issues

- OralBiome-AMP #48 — backport SSH fixes from OpenMM to Boltz-2 orchestrator (becomes obsolete after migration)
- OralBiome-AMP #49 — OpenMM Docker image slow SSH boot (handled in shared image build, not per-orchestrator)
- OralBiome-AMP #50 — parallelize failed job retries (implemented once in `BatchOrchestrator`, inherited by all)
- OralBiome-AMP #84 — orchestrator exits with pending jobs after worker silent crash (fixed in shared lifecycle, not per-orchestrator)
