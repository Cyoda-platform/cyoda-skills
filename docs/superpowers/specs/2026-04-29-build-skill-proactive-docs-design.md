# Build Skill: Proactive API Docs Lookup

**Date:** 2026-04-29
**Scope:** `cyoda/skills/build/SKILL.md` — Step 4 only

## Problem

Claude failed to register Cyoda entities on the first attempt because the build skill's Step 4 showed a hardcoded curl example for workflow import without first explaining that the entity model must be created. Claude only discovered the correct sequence (create model → import workflow → lock) after invoking `cyoda:docs` and running `cyoda help models` + `cyoda help workflows` — but only after 404 failures.

The fallback note "For API details, invoke `/cyoda:docs`" was present but positioned as optional recovery, not mandatory preparation.

## Design

### Step 4 change

Add a mandatory first sub-step: fetch the registration API from `cyoda help` before executing any commands.

**New Step 4 structure:**

1. **Fetch registration API** — run `cyoda help models` and `cyoda help workflows`, extract the correct endpoint patterns and required sequence
2. **Create entity model** — conceptual description only: registers the entity schema, enabling discovery mode
3. **Import workflow** — conceptual description only: attaches the state machine to the entity
4. **Lock schema** — conceptual description only: transitions from discover to strict mode
5. **Execute** — use the derived commands from step 1, show response, delegate errors to `/cyoda:debug`

### What stays in the skill

- Conceptual descriptions of each sub-step (what each operation means and why it exists)
- The canonical flow order: model → workflow → lock
- No curl examples, no hardcoded endpoint paths

### What is removed

- Hardcoded curl example for `/api/model/${ENTITY_NAME}/${MODEL_VERSION}/workflow/import`
- Fallback note "For API details on any endpoint, invoke `/cyoda:docs`" — superseded by the mandatory proactive lookup

## Why this works

The root cause was timing: Claude reached for docs *after* failure rather than *before* execution. Making the lookup mandatory at the top of Step 4 ensures Claude always has version-accurate API knowledge before issuing any curl commands, regardless of what's cached in the skill body.
