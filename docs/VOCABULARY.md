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


## Simplicity gate — v1.0.2

The owner directs that every addition earn its place: a concrete consumer need, a clear distinction, and a practical positive/negative example or executable check. If an addition remains ambiguous, costs disproportionate effort, or cannot be verified in a way that protects existing behavior, defer or omit it. Do not build an enforcement mechanism merely because a conceivable defect exists.

For vocabulary entries, a positive example shows what the term means and a contrasting example can show what it does not mean. This is not a requirement to automate natural-language meaning. For executable rules, use a passing fixture and a deliberately failing fixture. Keep semantic review proportionate to the actual use case; domain references remain appropriate for ordinary terms, while disputed or consequential definitions need specific sources.

Following the audit at `bfd55f4`, the existing checker now rejects missing version/scope, malformed source URL shape, blank classification definitions, repeated aliases, identical normalized definitions, and extra relationship fields. There are 16 negative controls in total. URL shape validation does not verify that a page exists; exact duplicate detection does not prove semantic distinctness. Do not add a second inventory, hardcoded duplicate role mapping, generic ontology engine, or artificial semantic assertions just to make tests green. A wrong but structurally valid relationship or mapping still needs human review. Existing entries and typed edges remain reviewable in the canonical JSON.

Five targeted definitions were clarified without adding concepts or changing role identifiers: primary key (constraint), rollback (SQL transaction), executable (filesystem permission context), error (detected problem), and failure (unsuccessful outcome). See the [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html) and [ROLLBACK](https://www.postgresql.org/docs/current/sql-rollback.html) documentation for the SQL distinctions. No palette, runtime, or policy changes. The 274 terms and 31 edges remain a bounded learning reference, not a proven universal ontology. Full semantic review and learner acceptance remain open; prioritize representative recognition examples before spending effort on unused distinctions.


## C04 — Representative semantic and readability review (v1.0.3)

Reviewed the exact v1.0.2 candidate at `df9d8a0`. The CI log confirms 274 terms, 10 domains, 31 relationships and 16 negative controls. The review below covers representative distinctions in each domain, not a certification of all individual terms or examples. Definitions remain independent of color. Clarified ten existing definitions without adding concepts or changing relationships, and added direct references for DNS, TLS, Docker storage and tracing.

| Domain | Positive recognition example | Contrast / non-example | Reference |
|---|---|---|---|
| Filesystem | `current -> releases/v1` is a symbolic link; it stores a path. | Two hard-linked names share an inode; neither is a path-storing symbolic link. | [Linux symlink(7)](https://man7.org/linux/man-pages/man7/symlink.7.html) |
| Shell | `printf '%s' hello` supplies an argument; `\|` joins commands into a pipeline. | A nonzero exit status is not success; a pipeline may need pipefail to expose an earlier command failure. | [Bash manual](https://www.gnu.org/software/bash/manual/bash.html) |
| Programming | In `function add(a,b) { return a+b; }`, a and b are parameters; 5 and 3 in add(5,3) are arguments. | A const binding cannot be reassigned; that does not make its referenced object immutable. | [MDN Parameter](https://developer.mozilla.org/en-US/docs/Glossary/Parameter) |
| Data | `PRIMARY KEY (id)` constrains row identity; `public.users` names a table in a database schema. | A JSON data schema describes structure; it is not a SQL namespace. | [PostgreSQL constraints](https://www.postgresql.org/docs/current/ddl-constraints.html), [schemas](https://www.postgresql.org/docs/current/ddl-schemas.html) |
| Version control | A commit records a snapshot and history links; a branch tracks a line of development. | A release tag does not advance automatically with each new commit on main. | [Git glossary](https://git-scm.com/docs/gitglossary) |
| Runtime | `node:22` is an image reference; a container is an instance created from an image. | A Docker-managed volume is not the same as mounting a particular host path. | [Docker overview](https://docs.docker.com/get-started/docker-overview), [storage](https://docs.docker.com/engine/storage/) |
| Networking | DNS retrieves name records; TLS protects communication; HTTP specifies request and response semantics. | DNS resolution does not establish encryption; an informational HTTP response is not necessarily the final outcome. | [RFC 1034](https://www.rfc-editor.org/rfc/rfc1034.html), [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446.html), [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html) |
| Delivery | The Color CI workflow contains check and docker jobs; each job has steps. | A runner executes a job; it is not the job itself. | [GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions) |
| Security | Signing in verifies an identity; checking whether that identity can write a file determines authorization. | Successful authentication alone does not grant permission to write. | [NIST authentication](https://csrc.nist.gov/glossary/term/authentication), [authorization](https://csrc.nist.gov/glossary/term/authorization) |
| Observability and outcomes | A trace connects spans; one database operation may be represented by one span. A known queued job is pending. | An absent job result with no evidence of its state is unknown, not success or confirmed pending. | [OpenTelemetry traces](https://opentelemetry.io/docs/concepts/signals/traces/), Color evidence-first convention |

### Read the complete vocabulary without maintaining another copy

From the repository root, the existing jq dependency can generate a readable grouped reference directly from the authoritative JSON. No new dependency, runtime feature, or checked-in duplicate is required.

```bash
jq -r '. as $v | .domains[] | .id as $domain | "\n=== " + .title + " ===", ($v.terms[] | select(.domain == $domain) | "\n" + (.id | gsub("_"; " ")) + "\n  Meaning: " + .definition + "\n  Example: " + .example + (if (.aliases | length) > 0 then "\n  Also called: " + (.aliases | join(", ")) else "" end))' docs/vocabulary.json
```

The representative review is complete for the listed distinctions; owner learning acceptance is still required. Unreviewed concepts remain reference material; do not automatically promote every vocabulary entry into a color role. If a later workflow requires another concept, verify it at that point. This closes the bounded review without an exhaustive ontology or additional validator.
