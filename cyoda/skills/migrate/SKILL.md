---
name: migrate
description: Lift-and-shift a Cyoda application from local cyoda-go to Cyoda Cloud. Exports entity models and workflows from local, sets up cloud instance, imports, and verifies. No code changes required — same API surface on both tiers.
allowed-tools: Bash(curl *) Bash(cat *) Bash(grep *) Bash(mkdir *) Bash(tee *) Bash(jq *)
---

## Cyoda Lift-and-Shift Migration

This migrates your entity models and workflows from local cyoda-go to Cyoda Cloud. Your application code does not change — just the `endpoint` and auth config.

Reading current local config:
```!
jq . .cyoda/config 2>/dev/null || echo '{"endpoint":"none"}'
```

If `"endpoint":"none"` or config is absent: *"No Cyoda endpoint configured. Run `/cyoda:setup` first."* Stop.

If `.env` equals `production`: display **"⚠️ Operating against a PRODUCTION Cyoda instance. Exports and imports will affect live data."**

If not pointing to a local instance (endpoint does not contain `localhost` or `127.0.0.1`): *"This skill migrates FROM local cyoda-go. Your current config points to a non-local endpoint. Are you sure you want to proceed?"*

### Step 1 — Verify local instance is working

```bash
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)
curl -sf --max-time 5 "${ENDPOINT}/readyz" || echo "UNREACHABLE"
```

If unreachable: *"Start local cyoda-go first (`cyoda`), then re-run this skill."* Stop.

Suggest running `/cyoda:test` against local before migrating to confirm everything works.

### Step 2 — Export entity models and workflows

```bash
mkdir -p migration
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)

# List all models
MODELS=$(curl -sf "${ENDPOINT}/api/model")
echo "$MODELS" | tee migration/models.json

# For each model, export workflow (run for each entity name and version)
curl -sf "${ENDPOINT}/api/model/${ENTITY_NAME}/${MODEL_VERSION}/workflow" \
  | tee migration/${ENTITY_NAME}_${MODEL_VERSION}_workflow.json
```

Show the user what was exported.

### Step 3 — Set up Cyoda Cloud

*"Now let's connect to Cyoda Cloud. I'll invoke `/cyoda:setup` (cloud mode)."*

Invoke `cyoda:setup` for cloud setup, then `cyoda:login` for authentication.

After setup: re-read `.cyoda/config` to confirm cloud endpoint is active.

### Step 4 — Import to cloud

```bash
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)
TOKEN=$(jq -r '.token' .cyoda/config)

# Import each workflow
curl -sf -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d @migration/${ENTITY_NAME}_${MODEL_VERSION}_workflow.json \
  "${ENDPOINT}/api/model/${ENTITY_NAME}/${MODEL_VERSION}/workflow/import"
```

Repeat for each exported workflow. Show success/failure per import.

### Step 5 — Verify

Invoke `/cyoda:test` against the cloud endpoint. All tests should pass identically to local.

### Step 6 — Update app config

*"Migration complete. Update your application to use:*
- *`endpoint`: {cloud endpoint}*
- *`token`: (from `/cyoda:login`)*

*The API surface is identical — no code changes needed."*

Show [templates/migration-checklist.md](templates/migration-checklist.md) as a reference.
