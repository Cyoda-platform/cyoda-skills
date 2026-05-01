# Cyoda Plugin Improvements — Auth, Build, and Self-Correction

**Date:** 2026-05-01
**Status:** Approved
**Based on:** Analysis of a full build + migrate session in `_developer/conversation.md`

## Problem

Three recurring failures observed in the conversation:

1. **Auth**: Claude tried 6+ OAuth endpoint paths before finding the correct one. The skill's "try these paths" note caused random guessing instead of consulting `cyoda help config auth`.
2. **Build**: Claude attempted to POST a workflow before the model existed, causing 404s. The `hello-world.md` example skipped the model-creation step entirely. The `entity-model.json` template referenced a non-existent API body format.
3. **Locking**: Claude locked models after posting minimal sample data. When the app later wrote richer entities, Cyoda rejected fields not present in the locked schema (`BAD_REQUEST: unexpected field not present in model`).

## Changes

### 1. cyoda:auth — Correct OAuth pattern + self-correction rule

**What changes:**
- Before the token call, run `cyoda help config auth` (if CLI is available) to confirm the current-version endpoint.
- Hard-code the known-good pattern as the primary attempt:
  - URL: `POST {endpoint}/api/oauth/token`
  - Auth: `Authorization: Basic base64(client_id:client_secret)` header
  - Body: `grant_type=client_credentials` (form-encoded, no credentials in body)
- Replace the vague "Common paths: ..." note with an error rule: *"If this returns 4xx/5xx, run `cyoda help config auth` to get the current endpoint for the installed version — do NOT try alternate paths."*

**Why Basic auth:** The Cyoda Cloud OAuth endpoint authenticates the client via the `Authorization: Basic` header, not via body parameters. Putting credentials in the body causes 403/500 errors.

### 2. cyoda:build — Correct model creation flow

**What changes in `hello-world.md`:**

Replace with the correct 3-step flow:
1. POST a sample entity → auto-creates the model in discover mode: `POST /api/entity/JSON/{entity}/1`
2. POST workflow: `POST /api/model/{entity}/1/workflow/import`
3. Done — no lock step

**What changes in `entity-model.json`:**

Remove this template. It documented `{"entityName": "...", "schemaMode": "discover"}` which does not correspond to any real API call. Replace with a file named `sample-entity.json` containing a representative payload: `{"field1": "example", "field2": 0}` — the actual body you POST to create a model in discover mode.

**What changes in `SKILL.md` Step 2 brainstorm menu:**

Remove "Lock schema" as a standard option. Add a discover-mode-first note:

> *"Schema stays in discover mode during development — Cyoda infers it automatically from the entities you post. Only consider locking when you're confident all fields are known and you're moving to production."*

**What changes in `SKILL.md` Step 4:**

Add self-correction rule: *"If any API call returns 4xx/5xx, run `cyoda help models` before retrying — do not guess alternate endpoints."*

### 3. New evals

Add to `cyoda/skills/auth/evaluations/`:
- **`eval-basic-auth-first-attempt.json`**: Claude uses Basic auth header with `/api/oauth/token` on the first attempt, not after iterating through paths.

Add to `cyoda/skills/build/evaluations/`:
- **`eval-model-before-workflow.json`**: Claude POSTs a sample entity before importing a workflow — model creation precedes workflow registration.
- **`eval-discover-mode-default.json`**: Claude does NOT suggest locking the schema during a normal development build session.

## What does NOT change

- `cyoda:migrate` — correct as-is
- `cyoda:setup` — correct as-is (already handles Homebrew permission failures correctly)
- CORS — not addressed here; will be fixed in cyoda-go directly
- All other skills — unaffected
