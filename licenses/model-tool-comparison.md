# Model & Tool License Comparison

Comprehensive license audit for all structure prediction models, docking tools, MD engines, force fields, cheminformatics libraries, and infrastructure used across Lambda Biolab projects. Last updated: 2026-04-13.

All license claims verified against first-party sources (linked).

---

## Structure Prediction Models

| Tool | Developer | License (Code) | License (Weights) | Commercial? | Copyleft? | Source |
|------|-----------|---------------|-------------------|-------------|-----------|--------|
| AlphaFold 2 | Google DeepMind | Apache 2.0 | CC-BY 4.0 | **Yes** | No | [LICENSE](https://github.com/google-deepmind/alphafold/blob/main/LICENSE) |
| AlphaFold 3 | Google DeepMind | CC-BY-NC-SA 4.0 | Custom proprietary (Google approval required) | **No** | Yes (ShareAlike on code) | [LICENSE](https://github.com/google-deepmind/alphafold3/blob/main/LICENSE) |
| Boltz-2 | MIT / Recursion | MIT | MIT | **Yes** | No | [LICENSE](https://github.com/jwohlwend/boltz/blob/main/LICENSE) |
| Chai-1 | Chai Discovery | CDCLA (custom) | CDCLA (custom) | **No** | No | [LICENSE.md](https://github.com/chaidiscovery/chai-lab/blob/main/LICENSE.md) |
| Chai-1r | Chai Discovery | Apache 2.0 | Apache 2.0 | **Yes** | No | [chai-lab repo](https://github.com/chaidiscovery/chai-lab) |
| ESMFold / ESM-2 | Meta FAIR | MIT | MIT | **Yes** | No | [LICENSE](https://github.com/facebookresearch/esm/blob/main/LICENSE) |
| ESM3 (open small) | EvolutionaryScale | Non-commercial | Non-commercial / API-only (large) | **No** | No | [evolutionaryscale.ai](https://www.evolutionaryscale.ai/) |
| ColabFold | Sergey Ovchinnikov | MIT | MIT | **Yes** | No | [LICENSE](https://github.com/sokrypton/ColabFold/blob/main/LICENSE) |

### AlphaFold 3 — detailed restrictions

AF3 uses a **triple-license structure**:
- **Code** (CC-BY-NC-SA 4.0): non-commercial, ShareAlike derivatives, attribution required
- **Weights** ([WEIGHTS_TERMS_OF_USE.md](https://github.com/google-deepmind/alphafold3/blob/main/WEIGHTS_TERMS_OF_USE.md)): must be obtained directly from Google (request form), non-transferable, non-sublicensable, Google can terminate at any time
- **Outputs** ([OUTPUT_TERMS_OF_USE.md](https://github.com/google-deepmind/alphafold3/blob/main/OUTPUT_TERMS_OF_USE.md)): non-commercial only, cannot train competing models, mandatory citation

---

## NVIDIA Generative Models

| Tool | Developer | License (Code) | License (Weights) | Commercial? | Source |
|------|-----------|---------------|-------------------|-------------|--------|
| Proteina | NVIDIA | Apache 2.0 | NVIDIA Open Model License | **Yes** | [GitHub](https://github.com/NVIDIA-Digital-Bio/proteina) |
| La-Proteina | NVIDIA | Apache 2.0 | NVIDIA Open Model License | **Yes** | [GitHub](https://github.com/NVIDIA-Digital-Bio/la-proteina) |
| Proteina-Complexa | NVIDIA | Apache 2.0 | NVIDIA Open Model License | **Yes** | [GitHub](https://github.com/NVIDIA-Digital-Bio/proteina-complexa) |

Note: [NVIDIA Open Model License](https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-open-model-license/) allows commercial use and derivatives but is not OSI-approved. Includes patent litigation termination clause and indemnification requirement.

---

## Docking Tools

| Tool | Developer | License | Commercial? | Copyleft? | Source |
|------|-----------|---------|-------------|-----------|--------|
| AutoDock Vina | Scripps Research | Apache 2.0 | **Yes** | No | [LICENSE](https://github.com/ccsb-scripps/AutoDock-Vina/blob/develop/LICENSE) |
| Vina-GPU 2.1 | Nanjing U | Apache 2.0 | **Yes** | No | [GitHub](https://github.com/DeltaGroupNJUPT/Vina-GPU-2.1) |
| GNINA | U Pittsburgh | Apache 2.0 / GPL-2.0 (dual) | **Yes** (conditions) | **Strong** (GPL path) | [GitHub](https://github.com/gnina/gnina) |

### GNINA licensing note

GNINA is dual-licensed. The binary as distributed links OpenBabel (GPL-2.0), making the distributed binary GPL-2.0 due to copyleft inheritance. The Apache-2.0 path is only available if OpenBabel references are removed from source.

---

## MD & Simulation

| Tool | Developer | License | Commercial? | Copyleft? | Source |
|------|-----------|---------|-------------|-----------|--------|
| OpenMM | Stanford | MIT + LGPL (GPU platforms) | **Yes** | Weak (LGPL GPU parts) | [licenses/](https://github.com/openmm/openmm/tree/master/licenses) |
| MDAnalysis | Community | LGPL-2.1+/3.0+ | **Yes** | Weak | [LICENSE](https://github.com/MDAnalysis/mdanalysis/blob/develop/LICENSE) |
| mdtraj | Community | LGPL-2.1 | **Yes** | Weak | [LICENSE](https://github.com/mdtraj/mdtraj/blob/main/LICENSE) |
| PDBFixer | OpenMM | MIT | **Yes** | No | [LICENSE](https://github.com/openmm/pdbfixer/blob/master/LICENSE) |
| ParmEd | Community | LGPL-2.1 | **Yes** | Weak | [GNU_LGPL_v2](https://github.com/ParmEd/ParmEd/blob/master/GNU_LGPL_v2) |

---

## Force Fields & Parameterization

| Tool | License | Commercial? | Copyleft? | Risk | Source |
|------|---------|-------------|-----------|------|--------|
| AmberTools / GAFF2 | GPL-3.0 (+ LGPL, BSD, MIT components) | **Yes** (with GPL obligations) | **Strong** | High | [ambermd.org/AmberTools.php](https://ambermd.org/AmberTools.php) |
| ACPYPE | GPL-3.0 | **Yes** (with GPL obligations) | **Strong** | High | [LICENSE](https://github.com/alanwilter/acpype/blob/master/LICENSE) |
| openmmforcefields | MIT (code only) | **Yes** (code) | No | Low (code) | [LICENSE](https://github.com/openmm/openmmforcefields/blob/main/LICENSE) |
| CHARMM36m params | **No explicit license** | **Unclear** | No | **High** | [mackerell.umaryland.edu](https://mackerell.umaryland.edu/charmm_ff.shtml) |
| CGenFF params | **No explicit license** | **Unclear** | No | **High** | [mackerell.umaryland.edu](https://mackerell.umaryland.edu/charmm_ff.shtml) |
| CGenFF program | Free (non-profit) / Commercial via SilcsBio | **Paid** (commercial) | N/A (proprietary) | High | [mackerell.umaryland.edu](https://mackerell.umaryland.edu/charmm_ff.shtml), [silcsbio.com](https://silcsbio.com) |

### CHARMM36m / CGenFF parameter files — gray area

The CHARMM36m and CGenFF parameter files (`.prm`, `.rtf`, `.str`) are freely downloadable from mackerell.umaryland.edu with no registration, no click-through, and no stated license. The download page contains no terms of use. The files themselves contain no copyright or license headers — only academic citations.

**For commercial use:** Contact the MacKerell lab (mackerell@rx.umaryland.edu) for written confirmation of usage terms. The openmmforcefields package redistributes these parameters under its MIT license, but this may not reflect the original authors' intent.

### AmberTools / GAFF2 — GPL copyleft

AmberTools (including GAFF2 parameters) is GPL-3.0. If called as a **subprocess** (not linked as a library), the copyleft obligation may not propagate to calling code — but this is legally debatable. Both projects use ACPYPE (also GPL-3.0) as a wrapper around AmberTools' antechamber.

Note: **Amber** (the full production MD suite) requires a paid commercial license. **AmberTools** is the free GPL-licensed subset.

---

## Cheminformatics & Utilities

| Tool | License | Commercial? | Copyleft? | Source |
|------|---------|-------------|-----------|--------|
| RDKit | BSD-3-Clause | **Yes** | No | [license.txt](https://github.com/rdkit/rdkit/blob/master/license.txt) |
| P2Rank | MIT | **Yes** | No | [GitHub](https://github.com/rdk/p2rank) |
| OpenBabel | GPL-2.0 | **Yes** (with copyleft) | **Strong** | [COPYING](https://github.com/openbabel/openbabel/blob/master/COPYING) |
| BioPython | Biopython License + BSD-3-Clause | **Yes** | No | [LICENSE.rst](https://github.com/biopython/biopython/blob/master/LICENSE.rst) |
| gemmi | MPL-2.0 | **Yes** | Weak (file-level) | [LICENSE.txt](https://github.com/project-gemmi/gemmi/blob/master/LICENSE.txt) |

---

## Cloud & Infrastructure

| Tool | License | Commercial? | Copyleft? | Source |
|------|---------|-------------|-----------|--------|
| SkyPilot | Apache 2.0 | **Yes** | No | [LICENSE](https://github.com/skypilot-org/skypilot/blob/master/LICENSE) |
| BioNeMo Framework | Apache 2.0 | **Yes** | No | [GitHub](https://github.com/NVIDIA/bionemo-framework) |

---

## Lab Notebook

| Tool | License | Commercial? | Copyleft? | Risk | Source |
|------|---------|-------------|-----------|------|--------|
| eLabFTW | AGPL-3.0 | Yes (heavy obligations) | **Strongest** (network clause) | **Very High** | [LICENSE](https://github.com/elabftw/elabftw/blob/master/LICENSE) |

eLabFTW uses the **AGPL-3.0** — the strongest common copyleft license. Any modifications served over a network (e.g., self-hosted with custom plugins) require full source disclosure under AGPL-3.0. Using it unmodified (self-hosted, no code changes) is fine.

---

## Summary: Commercial Use Risk Map

### Safe (permissive licenses)

Boltz-2 (MIT), Chai-1r (Apache), AlphaFold 2 (Apache/CC-BY), ESMFold (MIT), AutoDock Vina (Apache), Vina-GPU (Apache), RDKit (BSD), P2Rank (MIT), BioPython (BSD-like), PDBFixer (MIT), SkyPilot (Apache), ColabFold (MIT), openmmforcefields code (MIT)

### Manageable (weak copyleft — use as library, don't modify source)

OpenMM LGPL parts, MDAnalysis (LGPL), mdtraj (LGPL), ParmEd (LGPL), gemmi (MPL-2.0)

### Requires care (strong copyleft — subprocess isolation recommended)

AmberTools/GAFF2 (GPL-3.0), ACPYPE (GPL-3.0), OpenBabel (GPL-2.0), GNINA GPL path

### Requires action before commercial use

- **CHARMM36m / CGenFF params** — no license; contact MacKerell lab for written permission
- **CGenFF program** — commercial license required from SilcsBio
- **eLabFTW** — AGPL-3.0; do not modify without disclosing source
- **AlphaFold 3** — non-commercial only; separate agreement needed with Google

### Not suitable for commercial use (without separate agreement)

AlphaFold 3 (CC-BY-NC-SA + proprietary), Chai-1 original (CDCLA), ESM3 open model (non-commercial)
