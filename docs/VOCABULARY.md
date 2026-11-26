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
- **Data representation and databases:** 26 terms. Data structure, storage, integrity and change.
- **Version control and collaboration:** 25 terms. Git objects, references and operations.
- **Execution and infrastructure:** 29 terms. Components that make software run.
- **Networking and web interfaces:** 28 terms. How independent systems communicate.
- **Automation, testing and evidence:** 30 terms. Execution and verification vocabulary.
- **Security and access:** 15 terms. Identity, trust and permitted operations.
- **Observability, outcomes and state:** 22 terms. Signals and outcome terms, distinct from object identities.

## Verification

Run `python3 scripts/check-vocabulary.py` from the repository root. It verifies unique normalized IDs and aliases, domain/source references, complete fields, relation endpoints, subtype cycles and exact coverage of existing role, hierarchy and category values. The checker includes negative controls. No runtime dependency is added.


## Reusable library design method (v1.0.0)

**Purpose:** Build a reusable library of concepts, contracts, data, rules or software capabilities that is understandable, nonredundant within a declared scope, verifiable and safe to extend. This method is a documented reconstruction of the observable Color design decisions, not a claim that every recommended check has already been performed.

**Order of work:** purpose → inventory → scope → canonical units → distinctions → relationships → contracts → verification → adoption.

### 1. Start with the consumer and the outcome

Write one sentence describing who will use the library and what they need to accomplish. State the output and a measurable definition of done. Set exclusions before selecting technology or inventing entries. For a learning library, the consumer must be able to explain and recognize a concept without depending on its color. For a code library, the consumer must be able to call a documented capability and understand its inputs, outputs and failure modes.

### 2. Inventory before inventing

Inspect the existing implementation, data schemas, policies, consumers, tests and existing external libraries or primary references. Record exact revisions where possible. Identify what already exists, what is missing, and what must remain compatible. A proposed feature is not a missing capability until the inventory establishes that distinction.

### 3. Bound the domain

Choose domains from the consumer's real work, not an attempt to catalogue everything. Each domain must earn its place with a distinct purpose and representative examples. A complete library means complete against a declared coverage boundary, not complete against all possible future use cases. Document out-of-scope material and how gaps can be proposed.

### 4. Define a minimal canonical unit

Give each concept or capability one stable identifier and one primary home. Capture only fields necessary for discovery, understanding, integration and verification. Use separate fields for different responsibilities; do not overload one field with identity, relationships, presentation and operational state. For a vocabulary record, start with ID, domain, definition, recognition example and aliases. For a code API, start with name, purpose, inputs, outputs, invariants and failure behavior. Extend the contract only when a real consumer requires it.

### 5. Apply the admission and nonredundancy test

For each candidate, ask:

1. Is this already represented under a name, synonym, abbreviation or equivalent capability? If yes, reuse the canonical entry or add an alias.
2. Can two apparently similar entries be distinguished by an observable example, behavior or responsibility? If not, merge or defer them.
3. Is this a property, subtype, relationship, outcome or independent concept? Store it in the proper place rather than duplicating the base concept.
4. Is this within the declared scope, and does it help a consumer? If not, defer it.
5. Is its definition grounded in a relevant source or executable contract? If ambiguous, mark the review gap rather than inventing a distinction.

Normalize names for collision detection, but remember that spelling checks cannot prove semantic nonredundancy. Preserve genuine distinctions even when names resemble each other. For example, a parameter is a declared input; an argument is a supplied value. They should not be aliases.

### 6. Model only meaningful relationships

Use typed, directional relationships where they communicate a fact that a flat list cannot. Specify the direction and semantics of every relationship type. A subtype is not containment; containment is not a reference; a dependency is not ownership. Check that endpoints exist, reject duplicate edges, and prevent cycles where the relation must be acyclic. Do not create an ontology engine before the data and its consumers justify one.

### 7. Separate canonical data from policy and presentation

Keep definitions in one authoritative library, policy in its established location, and presentation or runtime bindings in adapters. Preserve stable IDs and use a compatibility mapping when existing names differ from canonical terms. Do not duplicate definitions into multiple independent authoritative files. Do not activate runtime behavior merely by adding a reference entry. Version changes deliberately; treat breaking changes to public contracts separately from compatible additions.

### 8. Establish verification layers

| Layer | Evidence | What it cannot prove |
|---|---|---|
| Structural | Parseability, required fields, uniqueness, valid identifiers | Meaning or usefulness |
| Referential | Existing domains, source references and relationship endpoints | Truth of every relationship |
| Compatibility | Coverage of existing public roles or APIs, unchanged unrelated behavior | Full consumer acceptance |
| Semantic | Inspect primary sources at the appropriate granularity, resolve ambiguous terms, compare near-neighbors, review examples | Individual learning effectiveness |
| Consumer | Real recognition tasks or representative API use, including failure cases | Universal future coverage |

Automate deterministic checks with positive and negative controls. A passing checker proves the tested contract, not more. Do not call a vocabulary semantically certified merely because its JSON is valid. Domain-level reference URLs are a starting point, not proof that each definition was individually verified. For high-stakes or disputed concepts, retain term-level source links or sections and a review disposition. For code libraries, use contract, integration and relevant compatibility tests.

### 9. Package and adopt incrementally

Publish the authoritative data or API, a concise user guide, examples, the checker or test suite, and a change rule. Run the smallest sufficient checks, inspect the exact revision and document remaining gaps. Introduce consumer integrations only after their required contracts are ready. Apply Frugal Execution: reuse verified evidence, batch related work, and continue through authorized gates without unnecessary handoffs.

### Decision record: Color vocabulary v1.0.0

Baseline: Color 3.1.2 at commit `2336cc8`. Vocabulary introduced in PR #13 at `90bea71`.

| Decision | Reason | Trade-off / limit |
|---|---|---|
| Build vocabulary before palette | Color is intended to teach technical recognition; visual distinctions need meaningful concepts first. | Defers styling and new runtime roles. |
| Scope to ten working domains | Covers the technical environments encountered by the intended learner. | Does not enumerate all of computing; coverage is a design choice, not a proven universal taxonomy. |
| One canonical concept ID; aliases as metadata | Avoid duplicate representations while retaining familiar spellings. | Homonyms and overlapping meanings still need semantic review. |
| Plain definition plus example | Supports recognition rather than memorizing labels alone. | Examples are illustrative; actual learning gain is not yet measured. |
| One primary domain per term | Keeps navigation and ownership simple. | Concepts may apply across domains; primary placement does not imply exclusive membership. |
| Preserve seven legacy hierarchy labels and eight role fields | Existing installations and associations should remain compatible. | Mixed structural and functional hierarchy semantics remain; no migration is attempted. |
| Add a role-to-term map | Existing eleven runtime role names can refer to canonical concepts without renaming roles. | The map is documentation data, not a runtime binding. |
| Use explicit typed relationships | Express meaningful distinctions without creating new colors. | Initial 25 edges are selective, not a complete graph. |
| Keep palette and runtime unchanged | Isolate vocabulary work from the accepted 3.1.2 runtime. | No new visual capability ships in this batch. |
| Add one standard-library checker and CI gate | Detect structural and referential defects early without introducing runtime dependencies. | Natural-language truth, source validity, semantic equivalence and learner comprehension require separate review. |

**Evidence at initial vocabulary commit:** 271 concepts, ten domains, 25 relationships, 22 domain reference URLs, and eleven existing role mappings. The initial uniqueness and referential checks passed; GitHub's `check` and `docker` jobs subsequently passed on `90bea71`. The checker contains eight negative controls. The initial method did not establish term-by-term source verification or learner acceptance; those remain open quality gates before treating the vocabulary as a fully reviewed semantic authority.

### Definition of done for a reusable library

- Scope and intended consumer are explicit.
- Every included unit is necessary, identifiable and understandable.
- Existing equivalents are reused; aliases and distinct meanings are justified.
- Required relationships and compatibility boundaries are documented.
- Deterministic checks pass; negative cases are tested.
- Source or behavioral verification supports material claims.
- A representative consumer can actually use the library.
- Known gaps, decisions and the next extension rule are recorded.

A library is ready for a stated purpose when these gates are satisfied for that purpose, not merely when it contains a large number of entries.


## Semantic review checkpoint — v1.0.1

The structural CI pass at `3f878a1` did not establish semantic correctness. A targeted source review of ambiguous or overlapping entries identified the following corrections. All existing IDs and role assignments remain intact; three distinctions were added rather than merging unlike meanings.

| Review area | Correction | Source |
|---|---|---|
| Filesystem | Explicitly scope Color's file concept to regular files; recognize the broader Linux sense. | [Linux inode(7)](https://man7.org/linux/man-pages/man7/inode.7.html) |
| Programming | Clarify const binding versus object mutability, TypeScript interface scope, and declared parameters versus supplied arguments; correct relation direction and type. | [MDN const](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/const), [MDN parameter](https://developer.mozilla.org/en-US/docs/Glossary/Parameter), [TypeScript interfaces](https://www.typescriptlang.org/docs/handbook/interfaces) |
| Data | Separate a data schema from a PostgreSQL database namespace. | [PostgreSQL schemas](https://www.postgresql.org/docs/current/ddl-schemas.html) |
| Git | Distinguish Git references, tags, objects, HEAD and staging index; tag targets are not restricted to commits. | [Git glossary](https://git-scm.com/docs/gitglossary) |
| Networking | Separate Internet Protocol (IP) from an IP address; clarify HTTP method. | [RFC 8200](https://www.rfc-editor.org/rfc/rfc8200.html), [RFC 4291](https://www.rfc-editor.org/info/rfc4291/), [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html) |
| Execution | Distinguish images, containers, bind mounts and volumes; clarify exported environment variables. | [Docker overview](https://docs.docker.com/get-started/docker-overview), [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/), [GNU Bash manual](https://www.gnu.org/software/bash/manual/bash.html) |
| Delivery | Scope action, job and runner to GitHub Actions in these entries. | [GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions) |

Coverage after this batch: 274 concepts, 10 domains, 31 relationships. This is a targeted semantic correction, not a term-by-term certification of the whole vocabulary. Further review must assess remaining meanings, homonyms and examples against primary sources; learner recognition is still untested. Do not promote the vocabulary to color-assignment authority until those gates are met.

For reading the canonical library without editing it, use `jq -r '.terms[] | [.id, .definition, .example] | @tsv' docs/vocabulary.json` from the repository root. For a single entry, use `jq '.terms[] | select(.id == "parameter")' docs/vocabulary.json`.
