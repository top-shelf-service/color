# RLD-001 — Reusable Library Design and Execution Method

Version: 1.1.0
Status: transferable reference; TOS adoption requires reconciliation with its existing contracts.
Origin: accepted Color v3.3.0 (c362ec280b82d0af2e92bb8139e8efbdfd9126f1). Historical method and decisions: [Vocabulary](VOCABULARY.md#reusable-library-design-method-v100).

## Formula

**Define the outcome → reverse-plan prerequisites → inventory and reuse → select by impact → define the smallest testable unit → execute forward → verify → document → accept and freeze.**

This method applies to libraries of concepts, data, rules, contracts and callable capabilities. It is independent of implementation language, storage, rendering, host and application. It is a decision method, not a required new runtime framework.

## 1. Work backward from the outcome

State the consumer, observable outcome, scope and definition of done before choosing technology. Ask what must be true immediately before the outcome can occur; repeat until reaching an existing verified baseline or the smallest missing prerequisite. Turn this dependency order into a short forward-execution checklist. Preserve existing working behavior. Maintain one current task and one next task in the existing tracker. Completed means evidence supports the stated exit condition, not merely that code exists.

## 2. Inventory and admission

Inspect current implementation, canonical data, policies, consumers, tests and relevant established solutions before proposing additions. For each candidate:

- Is it necessary for the stated outcome, or does it address an observed material risk?
- Is an equivalent already present? Reuse it, expose it through a thin interface, or use an alias rather than duplicating it.
- Is the responsibility or meaning independently distinguishable? Clarify, merge, defer or omit ambiguity.
- Can the intended behavior and a meaningful counterexample or failure be demonstrated? For executable behavior, use a positive and a negative test. For reference knowledge, use a grounded example and contrasting example when meaningful; do not pretend to automate truth.
- Can it be introduced without breaking accepted contracts? If evidence is missing, state the gap and defer until it is resolved.

A candidate that cannot justify its existence does not become an implementation task. Record useful deferred ideas as issues rather than letting them interrupt the active goal.

## 3. Prioritize by mission impact, not implementation effort

Order admitted work by the consequence of leaving the need unmet: (1) integrity, recoverability and prerequisites that protect or enable the outcome; (2) direct improvement of the consumer's primary outcome; (3) removal of recurring operational friction or meaningful risk; (4) convenience without a demonstrated outcome improvement. Consider actual exposure and evidence, not hypothetical severity alone. If two items compete, prefer the one that unblocks the other or has the greater demonstrated impact. Effort is a sizing constraint: split the selected work into bounded testable slices, but do not promote low-impact work just because it is easy. No fabricated numerical impact scores are required.

## 4. Canonical unit and relationships

One stable identifier, one authoritative definition or contract, one primary home. For a concept, retain identity, meaning, example and aliases when needed; for a capability, retain purpose, inputs, outputs, invariants and failure behavior. These are starting points, not mandatory schemas. Distinguish identity, properties, relationships, policy, presentation and state. Represent only relationships that convey a useful distinct fact; define their direction and meaning, validate endpoints, and reject invalid cycles where applicable. Keep policy separate from canonical data and adapters. Preserve compatibility; do not create a new schema or engine unless an actual consumer requires it.

## 5. Execute forward in vertical slices

Use existing operations, compose them in dependency order, and expose only the commands or interfaces the consumer needs. Internal functions need not become public interfaces. Each operation must have a clear success/failure outcome. For mutations, validate prerequisites, preserve recoverable state where appropriate, stage and validate candidates before promotion where feasible, verify the result, and recover or fail closed if a gate fails. A lock or coordination mechanism is justified only by a real conflict risk. Do not generalize a specific recovery mechanism beyond evidence.

For substantial work, use bounded operations, parallel independent reads, serialized dependent writes, and checkpoints containing exact revision, evidence, remaining work and next action. A checkpoint is not an approval barrier; proceed within authority when gates pass.

## 6. Verification

| Layer | Evidence |
|---|---|
| Structural | Required shape, unique identifiers, deterministic checks. |
| Referential | Valid references and meaningful relationships. |
| Compatibility | Existing contracts and regression tests remain valid. |
| Semantic | Meaning and distinctions supported by appropriate sources or examples. |
| Consumer | Representative actual use in the target environment. |

Apply the layers relevant to the unit and consequence. A positive case proves intended behavior; a negative case proves a defined invalid or failure condition is handled. Green CI does not prove semantic truth, deployment, recovery from untested faults, or learning effectiveness. Unknown and pending are not pass. Require exact-head checks, scope/review audit and post-change verification where applicable. Do not add an enforcement mechanism merely to satisfy a conceptual concern.

## 7. Documentation and acceptance

Maintain the canonical library or implementation, concise consumer instructions, a test or example, a decision record, and a current task checklist. Reuse existing authoritative locations; reference exact revisions instead of duplicating editable facts. Record the reason, boundaries, accepted evidence, known gaps and extension rule. For a completed version, verify the actual baseline, then tag or otherwise pin it and close the applicable milestone. Do not move accepted tags to absorb subsequent work. Keep open issues outside completed milestones unless actually delivered.

**Definition of done:** consumer outcome and scope defined; smallest necessary unit delivered; existing behavior preserved; applicable positive/negative evidence passes; representative consumer acceptance obtained; limitations and deferred work documented; accepted baseline identifiable. Freeze development once the stated outcome is satisfied. Reopen only for demonstrated need or explicitly selected work.

## Worked evidence and limits

Color v3.3.0 demonstrates a working baseline, vocabulary separation, incremental rendering changes, a composed update command, positive/negative tests, an owner-observed installation/update, and a closed [milestone](https://github.com/top-shelf-service/color/milestone/1) with [tag](https://github.com/top-shelf-service/color/tree/v3.3.0). The vocabulary was accepted as a bounded reference, not a fully certified ontology. Daily learning effectiveness remains unmeasured; hard-kill/power-loss recovery remains manual. These are explicit limitations, not proof that the method works universally.

Transfer to TOS: adopt the method and its admission/verification rules only after comparing them with existing TOS/TSAL contracts; do not import Color implementation, palette, command names, or storage layout. Validate on a real TOS use case before declaring adoption complete.
