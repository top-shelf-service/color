# Technical vocabulary library

The [canonical vocabulary](vocabulary.json) defines technical concepts independently of color assignments. This is the initial bounded library for the Linux/Bash, programming, Git, runtime, data, networking, delivery, security and observability workflows that Color supports or may support. It is not a claim to enumerate every computing term. Definitions are concise learning explanations, with domain references for checking terminology in context; examples are illustrative, not commands to execute.

## Reading a record

Each term has one canonical ID, one domain, a plain-language definition, a recognition example and optional aliases. Aliases resolve to the same concept rather than becoming new roles. Related but different concepts retain their own IDs (e.g. authentication and authorization; image and container; parameter and argument). A term can be used in several contexts; its domain is its primary home, not an exclusive type system. The existing role-to-term map preserves the shipped role names. The hierarchy and category dictionaries explain the existing values without renaming them. Explicit typed relationships describe concepts; they do not imply any new color mapping.

## Change rule

Before adding a term, search the canonical IDs and aliases, distinguish it from existing concepts, give a recognizable example and identify the reference domain. Add a relationship only if it conveys a distinct fact. Do not assign a hex value or introduce a runtime role just because a term exists. Existing role data, laws, installer and runtime remain unchanged. Keep domain references and definitions reviewable; machine validation checks structure and consistency, not the truth of all natural-language definitions. A semantic review is required for future vocabulary changes.

## Domain inventory

- **Filesystem and storage:** 21 terms. Objects and paths you encounter in Linux listings.
- **Shell and command line:** 28 terms. How commands are expressed, connected and evaluated.
- **Programming and types:** 50 terms. Elements within source code, distinct from the identity of the source file.
- **Data representation and databases:** 25 terms. Data structure, storage, integrity and change.
- **Version control and collaboration:** 24 terms. Git objects, references and operations.
- **Execution and infrastructure:** 29 terms. Components that make software run.
- **Networking and web interfaces:** 27 terms. How independent systems communicate.
- **Automation, testing and evidence:** 30 terms. Execution and verification vocabulary.
- **Security and access:** 15 terms. Identity, trust and permitted operations.
- **Observability, outcomes and state:** 22 terms. Signals and outcome terms, distinct from object identities.

## Verification

Run `python3 scripts/check-vocabulary.py` from the repository root. It verifies unique normalized IDs and aliases, domain/source references, complete fields, relation endpoints, subtype cycles and exact coverage of existing role, hierarchy and category values. The checker includes negative controls. No runtime dependency is added.
