# Plugin Improvements — Auth, Build, Discover Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three failure patterns observed in a real build+migrate session: wrong OAuth auth method, missing model-creation step before workflow import, and premature schema locking.

**Architecture:** All changes are to skill markdown files and eval JSON files — no code. Tasks follow a write-eval-then-fix-skill pattern so assertions exist before the skill changes that satisfy them.

**Tech Stack:** Markdown skill files, JSON eval files, skill-creator plugin for running evals.

---

### Task 1: Fix cyoda:auth Step 3 — correct OAuth endpoint and Basic auth

**Files:**
- Modify: `cyoda/skills/auth/SKILL.md`

- [ ] **Step 1: Open the file and locate Step 3**

Read `cyoda/skills/auth/SKILL.md`. The section to replace is Step 3 — Obtain JWT token (lines ~47–57). Current content:

```bash
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)
TOKEN_RESPONSE=$(curl -sf -X POST "${ENDPOINT%/}/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")
echo "$TOKEN_RESPONSE"
```

Note below it: *"Verify the exact OAuth token endpoint path against the Cyoda OpenAPI spec. Common paths: `/oauth/token`, `/auth/token`, `/api/auth/token`."*

- [ ] **Step 2: Replace Step 3 with correct pattern**

Replace the entire Step 3 block with:

````markdown
**Step 3 — Obtain JWT token:**

If the cyoda CLI is installed, first confirm the current-version endpoint:
```bash
which cyoda >/dev/null 2>&1 && cyoda help config auth --format=markdown 2>/dev/null | head -40
```

Then call the token endpoint using Basic auth (client credentials in the `Authorization` header, not the request body):

```bash
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)
CREDENTIALS=$(printf "%s" "${CLIENT_ID}:${CLIENT_SECRET}" | base64)
TOKEN_RESPONSE=$(curl -sf -X POST "${ENDPOINT%/}/api/oauth/token" \
  -H "Authorization: Basic ${CREDENTIALS}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials")
echo "$TOKEN_RESPONSE"
```

If this returns 4xx/5xx: run `cyoda help config auth` to get the current-version endpoint for your installation. Do NOT try alternate paths — fix the one call based on what `cyoda help` tells you.

If the curl fails or returns an error: show the error and stop. Do not write partial credentials.
````

- [ ] **Step 3: Verify the file looks right**

Read `cyoda/skills/auth/SKILL.md` and confirm:
- Step 3 uses `Authorization: Basic` header
- Credentials are NOT in the `-d` body
- URL is `/api/oauth/token`
- Error rule says to run `cyoda help config auth`, not to try alternate paths

- [ ] **Step 4: Commit**

```bash
git add cyoda/skills/auth/SKILL.md
git commit -m "fix(auth): correct OAuth endpoint to /api/oauth/token with Basic auth header"
```

---

### Task 2: Add auth eval for Basic auth first attempt

**Files:**
- Modify: `cyoda/skills/auth/evaluations/evals.json`

- [ ] **Step 1: Read the current evals file**

Read `cyoda/skills/auth/evaluations/evals.json`. It has 4 evals (ids 1–4).

- [ ] **Step 2: Append new eval id 5**

Add the following as the 5th entry in the `"evals"` array (after the closing `}` of eval 4, before the final `]`):

```json
,{
  "id": 5,
  "prompt": "/cyoda:auth — connect to a Cyoda Cloud dev environment with client_id=abc123 and client_secret=xyz789",
  "expected_output": "Uses Authorization: Basic header with base64-encoded client_id:client_secret against /api/oauth/token on the first attempt, without iterating through multiple paths",
  "files": {
    ".cyoda/config": "{\"endpoint\": \"https://client-1edf4e3da14e497baf58d3aeb621ac40-dev.eu.cyoda.net\"}"
  },
  "assertions": [
    { "id": "basic-auth-header", "text": "Uses Authorization: Basic header with base64-encoded client_id:client_secret — credentials are NOT in the request body", "type": "behavior" },
    { "id": "correct-endpoint-first", "text": "Calls /api/oauth/token on the first attempt — does NOT try /oauth/token, /auth/token, or other paths first", "type": "behavior" },
    { "id": "no-path-guessing", "text": "Does NOT iterate through multiple token endpoint paths on failure — consults cyoda help config auth instead", "type": "behavior" },
    { "id": "consults-cyoda-help-on-failure", "text": "If token call fails, runs 'cyoda help config auth' before retrying — does not guess alternate paths", "type": "behavior" }
  ]
}
```

- [ ] **Step 3: Verify JSON is valid**

```bash
python3 -m json.tool cyoda/skills/auth/evaluations/evals.json > /dev/null && echo "valid"
```

Expected: `valid`

- [ ] **Step 4: Commit**

```bash
git add cyoda/skills/auth/evaluations/evals.json
git commit -m "test(auth): add eval for Basic auth on first attempt, no path guessing"
```

---

### Task 3: Rewrite hello-world.md with correct 3-step flow

**Files:**
- Modify: `cyoda/skills/build/examples/hello-world.md`

- [ ] **Step 1: Read current file**

Read `cyoda/skills/build/examples/hello-world.md`. The current version skips model creation (posts directly to `/api/model/{entity}/1/workflow/import` without first posting a sample entity).

- [ ] **Step 2: Rewrite with correct 3-step flow**

Replace the entire file content with:

```markdown
# Hello World — Minimal Cyoda App

The minimal first increment: one entity (`hello`) with a two-state workflow.

## Step 1 — Create the model (discover mode)

Post a sample entity. Cyoda auto-creates the model in discover mode — no upfront schema definition needed.

```bash
curl -X POST http://localhost:8080/api/entity/JSON/hello/1 \
  -H 'Content-Type: application/json' \
  -d '{"message": "Hello, Cyoda!"}'
# returns: [{"entityIds":["<uuid>"],"transactionId":"<uuid>"}]
```

## Step 2 — Import the workflow

```bash
curl -X POST http://localhost:8080/api/model/hello/1/workflow/import \
  -H 'Content-Type: application/json' \
  -d '{
    "workflows": [{
      "version": "1",
      "name": "hello-wf",
      "initialState": "draft",
      "active": true,
      "states": {
        "draft": {
          "transitions": [
            { "name": "submit", "next": "submitted", "manual": true }
          ]
        },
        "submitted": {}
      }
    }]
  }'
```

## Step 3 — Trigger a transition

```bash
curl -X PUT http://localhost:8080/api/entity/JSON/<ENTITY_ID>/submit
```

> **Stay in discover mode during development.** The schema evolves automatically as you post entities. Only consider locking the schema when you're confident all fields are known and you're moving to production.
```

- [ ] **Step 3: Verify the file no longer contains the pre-Step-1 model import pattern**

```bash
grep -n "workflow/import" cyoda/skills/build/examples/hello-world.md
```

Expected: only one match, after the sample entity POST step.

- [ ] **Step 4: Commit**

```bash
git add cyoda/skills/build/examples/hello-world.md
git commit -m "fix(build): rewrite hello-world with correct 3-step flow — entity POST before workflow import"
```

---

### Task 4: Replace entity-model.json template with sample-entity.json

**Files:**
- Delete: `cyoda/skills/build/templates/entity-model.json`
- Create: `cyoda/skills/build/templates/sample-entity.json`

- [ ] **Step 1: Delete entity-model.json**

```bash
git rm cyoda/skills/build/templates/entity-model.json
```

The deleted file contained `{"entityName": "${ENTITY_NAME}", "modelVersion": "1", "schemaMode": "discover"}` — this does not correspond to any real Cyoda API call and causes confusion.

- [ ] **Step 2: Create sample-entity.json**

Create `cyoda/skills/build/templates/sample-entity.json` with content:

```json
{
  "field1": "example",
  "field2": 0
}
```

This is the body for `POST /api/entity/JSON/{entityName}/{version}` that auto-creates the model in discover mode.

- [ ] **Step 3: Commit**

```bash
git add cyoda/skills/build/templates/sample-entity.json
git commit -m "fix(build): replace entity-model.json with sample-entity.json — correct API body format"
```

---

### Task 5: Update build SKILL.md — discover mode default, template ref, error rule

**Files:**
- Modify: `cyoda/skills/build/SKILL.md`

- [ ] **Step 1: Read the file**

Read `cyoda/skills/build/SKILL.md`. Three locations need changes:
- Step 2 brainstorm menu (remove "Lock schema", add discover note)
- Step 3 template reference (`entity-model.json` → `sample-entity.json`)
- Step 4 error handling (add self-correction rule)

- [ ] **Step 2: Update Step 2 brainstorm menu**

Find this block in Step 2:

```markdown
Ask: *"What would you like to add or change? Options:*
- *New entity model with workflow*
- *New state to an existing entity*
- *New transition between states*
- *Add criteria to a transition*
- *Add a processor to a transition*
- *Lock schema (move from discover to strict mode)*
- *Something else"*
```

Replace with:

```markdown
Ask: *"What would you like to add or change? Options:*
- *New entity model with workflow*
- *New state to an existing entity*
- *New transition between states*
- *Add criteria to a transition*
- *Add a processor to a transition*
- *Something else"*

> Schema stays in **discover mode** during development — Cyoda infers it automatically from the entities you post. Only lock the schema when you're confident all fields are known and you're moving to production.
```

- [ ] **Step 3: Update Step 3 template reference**

Find this line in Step 3:

```markdown
Use [templates/workflow.json](templates/workflow.json) and [templates/entity-model.json](templates/entity-model.json) as starting points.
```

Replace with:

```markdown
Use [templates/workflow.json](templates/workflow.json) and [templates/sample-entity.json](templates/sample-entity.json) as starting points.
```

- [ ] **Step 4: Update Step 4 error handling**

Find this line in Step 4:

```markdown
Show the response. If error: delegate to `/cyoda:debug` for diagnosis.
```

Replace with:

```markdown
Show the response. If the call returns 4xx/5xx: run `cyoda help models` before retrying — do not guess alternate endpoints. Then delegate to `/cyoda:debug` for persistent issues.
```

- [ ] **Step 5: Verify changes**

```bash
grep -n "Lock schema" cyoda/skills/build/SKILL.md
```

Expected: no matches.

```bash
grep -n "entity-model.json" cyoda/skills/build/SKILL.md
```

Expected: no matches.

```bash
grep -n "discover mode" cyoda/skills/build/SKILL.md
```

Expected: at least one match in the Step 2 area.

- [ ] **Step 6: Commit**

```bash
git add cyoda/skills/build/SKILL.md
git commit -m "fix(build): discover mode default, remove lock-schema menu option, add self-correction rule"
```

---

### Task 6: Add two new build evals

**Files:**
- Modify: `cyoda/skills/build/evaluations/evals.json`

- [ ] **Step 1: Read the current evals file**

Read `cyoda/skills/build/evaluations/evals.json`. It has 4 evals (ids 1–4).

- [ ] **Step 2: Append eval 5 — model creation precedes workflow import**

Add as the 5th entry in the `"evals"` array:

```json
,{
  "id": 5,
  "prompt": "/cyoda:build — register a new Order entity with draft and submitted states on a fresh instance",
  "expected_output": "Posts a sample entity to create the model in discover mode before importing the workflow — does not call workflow/import as the first API call",
  "files": {
    ".cyoda/config": "{\"endpoint\": \"http://localhost:8080\", \"env\": \"development\"}"
  },
  "assertions": [
    { "id": "entity-post-before-workflow", "text": "POSTs a sample entity to /api/entity/JSON/{entity}/1 before calling /api/model/{entity}/1/workflow/import", "type": "behavior" },
    { "id": "no-workflow-first", "text": "Does NOT call /api/model/{entity}/1/workflow/import as the first API call on a fresh instance", "type": "behavior" },
    { "id": "discover-mode-default", "text": "Does NOT lock the schema — stays in discover mode after workflow import", "type": "behavior" }
  ]
}
```

- [ ] **Step 3: Append eval 6 — no lock suggestion during dev build**

Add as the 6th entry:

```json
,{
  "id": 6,
  "prompt": "/cyoda:build — I want to add a ChatRoom entity and a Message entity",
  "expected_output": "Builds both entities in discover mode without suggesting or performing schema locking — mentions discover mode stays active during development",
  "files": {
    ".cyoda/config": "{\"endpoint\": \"http://localhost:8080\", \"env\": \"development\"}"
  },
  "assertions": [
    { "id": "no-lock-suggestion", "text": "Does NOT suggest locking the schema during a normal development build session", "type": "behavior" },
    { "id": "no-lock-execution", "text": "Does NOT execute a schema lock operation", "type": "behavior" },
    { "id": "mentions-discover-mode", "text": "Mentions that schema stays in discover mode during development", "type": "behavior" }
  ]
}
```

- [ ] **Step 4: Verify JSON is valid**

```bash
python3 -m json.tool cyoda/skills/build/evaluations/evals.json > /dev/null && echo "valid"
```

Expected: `valid`

- [ ] **Step 5: Commit**

```bash
git add cyoda/skills/build/evaluations/evals.json
git commit -m "test(build): add evals for model-before-workflow and discover-mode-default"
```

---

### Task 7: Run evals and verify

- [ ] **Step 1: Run auth evals**

Invoke the `skill-creator:skill-creator` skill with the prompt:

```
Run evals for the cyoda:auth skill from cyoda/skills/auth/evaluations/evals.json. Focus on eval id 5 (Basic auth first attempt) but run all evals and report pass/fail per assertion.
```

Expected: all existing evals (1–4) still pass; eval 5 passes with `basic-auth-header`, `correct-endpoint-first`, `no-path-guessing`, and `consults-cyoda-help-on-failure` all green.

- [ ] **Step 2: Run build evals**

Invoke the `skill-creator:skill-creator` skill with the prompt:

```
Run evals for the cyoda:build skill from cyoda/skills/build/evaluations/evals.json. Focus on evals 5 and 6 (model-before-workflow, discover-mode-default) but run all evals and report pass/fail per assertion.
```

Expected: existing evals (1–4) still pass; evals 5 and 6 pass.

- [ ] **Step 3: Fix any regressions**

If any previously-passing eval now fails, update the relevant skill file to restore it. Re-run the affected eval before committing.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add cyoda/skills/auth/SKILL.md cyoda/skills/build/SKILL.md
git commit -m "fix: restore eval regressions after improvements"
```
