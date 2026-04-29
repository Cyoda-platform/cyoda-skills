---
name: design
description: Brainstorm and design a Cyoda application. Guides entity modeling, workflow design, and compute node decisions following Cyoda philosophy. Auto-invoked when the user describes an app idea or asks how to model their domain in Cyoda.
when_to_use: When the user describes an application they want to build on Cyoda, asks how to model their domain, or needs help designing entities and workflows.
---

## Cyoda Application Design

### Phase 1 — Orientation (skip if user is already familiar with Cyoda)

Assess whether the user needs orientation. **Skip orientation if the user's message contains any of these Cyoda-specific terms:** `entity`, `entities`, `workflow`, `workflows`, `state`, `states`, `transition`, `transitions`, `compute node`, `discover mode`, `lock mode`. If the user already speaks Cyoda — go straight to Phase 2.

If none of those terms appear, give a brief orientation first:

**Orientation (2-3 sentences maximum):**

Cyoda is an Entity Database Management System (EDBMS) — a database where every record is a state machine. Instead of storing rows in tables, you define **entities** — domain objects like Orders or Users — each with a **workflow**: a set of named states and the transitions between them. Nothing in Cyoda is overwritten; every transition produces a new immutable revision, giving you the full history of every entity.

After orientation, ask: *"Does that make sense? Ready to design your app?"*

### Phase 2 — Domain Brainstorm

Ask one question at a time. Wait for the answer before asking the next.

**Q1:** *"What are the main domain objects in your application that have an independent lifecycle — things that change over time on their own clock?"*

For each entity identified, continue:

**Q2:** *"For [entity name]: what states does it move through from creation to completion? (e.g., for an Order: draft → submitted → processing → shipped → delivered)"*

**Q3:** *"For each transition: what triggers it? Manual action by a user, an incoming event/message, a time delay, or automatically when a condition is met?"*

**Q4:** *"Do any transitions need to call external code — to validate data, call a third-party API, or run a calculation? If yes, that's where a compute node comes in. But many apps don't need them at all."*

Present the compute node option neutrally — it is **optional**. Many workflows work purely with Cyoda's built-in criteria and processors.

**Q5:** *"Are you building this as a prototype or targeting production? This determines the schema mode:*
- *Discover mode (prototype): Cyoda infers and evolves the schema automatically as data is posted — no upfront field definitions needed.*
- *Lock mode (production): The schema is fixed. Data that doesn't match is rejected. Use this when the model is stable.*

*You can always start with discover and switch to lock when you're ready to go live. Which fits where you are now?"*

### Phase 3 — Output Design Summary

Present a structured summary:

```
Entities:
  - [EntityName]: states=[...], key transitions=[...]
  - ...

Compute nodes needed: yes/no
  - If yes: which transitions call external code and why

Schema mode: discover (prototype) / lock (production)

Suggested first increment for /cyoda:build: [EntityName] with [minimal workflow]
```

Reference patterns from [patterns.md](resources/patterns.md) when relevant (e.g., if the user describes an approval process, mention the Approval Flow pattern).

Offer to proceed: *"Ready to build this? Run `/cyoda:build` to start registering these models in your running Cyoda instance."*
