# Cyoda Plugin Design

**Date:** 2026-04-24
**Updated:** 2026-04-27
**Status:** Implemented

## Overview

A Claude Code plugin (`cyoda`) that helps developers implement, test, and run applications built on Cyoda — an Entity Database Management System (EDBMS). The plugin replaces AI Studio as the primary AI-assisted development environment for Cyoda applications, supporting the full journey from local cyoda-go development through lift-and-shift to Cyoda Cloud.

Cyoda is the database/platform, not the application. Users build their own apps in any language; those apps use Cyoda via REST and gRPC APIs. The plugin helps with the Cyoda side: entity models, workflows, compute nodes, and instance management.

## Target Users

Both newcomers (no prior Cyoda knowledge) and experienced developers needing AI assistance with specific tasks. The plugin serves both through a thin orchestrator skill for newcomers and atomic skills for precision work.

## Plugin Structure

```
cyoda/
├── .claude-plugin/
│   └── plugin.json             ← manifest (name: "cyoda")
├── skills/
│   ├── status/
│   │   └── SKILL.md
│   ├── docs/
│   │   └── SKILL.md
│   ├── setup/
│   │   └── SKILL.md
│   ├── login/
│   │   └── SKILL.md
│   ├── design/
│   │   └── SKILL.md
│   ├── build/
│   │   └── SKILL.md
│   ├── compute/
│   │   └── SKILL.md
│   ├── test/
│   │   └── SKILL.md
│   ├── debug/
│   │   └── SKILL.md
│   ├── migrate/
│   │   └── SKILL.md
│   └── app/
│       └── SKILL.md
├── monitors/
│   └── monitors.json           ← watches .cyoda/config, notifies Claude on changes
└── README.md
```

Each skill directory may contain `examples/`, `templates/`, and `resources/` subdirectories for supporting files. These are referenced from `SKILL.md` but never embedded inline, keeping each `SKILL.md` under 500 lines. Each skill should include an `evaluations/` directory with JSON eval files covering representative scenarios.

## Skill Catalog

| Skill | Invocation | context | Purpose |
|---|---|---|---|
| `cyoda:status` | Both (Claude auto) | inline | Report connection status: "Connected to [Local/Cloud] — v1.4.2" |
| `cyoda:docs` | Both (user + Claude auto) | inline | Documentation via `cyoda help` + web; synthesizes answers |
| `cyoda:design` | Both | inline | Domain brainstorm: entities, workflows, philosophy orientation |
| `cyoda:build` | User-only | inline | Incremental build loop: inspect → brainstorm → generate → register → verify |
| `cyoda:compute` | Both | inline | Compute node patterns: gRPC protocol, connection lifecycle, processor/criteria |
| `cyoda:test` | User-only | fork | Smoke test: guided scripts + direct execution against running instance |
| `cyoda:debug` | Both | inline | Diagnose: failed transitions, processor errors, connectivity |
| `cyoda:setup` | User-only | inline | Provision Cyoda: local cyoda-go install OR cloud connection config |
| `cyoda:login` | User-only | inline | Obtain JWT token, write endpoint + token to `.cyoda/config` with env safety guard |
| `cyoda:migrate` | User-only | inline | Lift-and-shift: export local → cloud setup → import → verify |
| `cyoda:app` | User-only | inline | Newcomer orchestrator: orients to Cyoda philosophy, then sequences other skills |

`cyoda:build` is `inline` (not `fork`) because the incremental build loop requires interactive back-and-forth in the main conversation.

## Skill Invocation Control

All skills can be invoked by both users and Claude. Sensitive actions are guarded by explicit confirmation prompts within the skill itself:

- `cyoda:login` — requires explicit `yes` before storing production credentials
- `cyoda:build` — displays a prominent production warning and confirms before each registration when `env=production`
- `cyoda:setup` — asks the user to confirm the mode (local vs cloud) before proceeding
- `cyoda:migrate`, `cyoda:test` — confirm before making changes to a target instance

Skills that provide knowledge or guidance (`cyoda:status`, `cyoda:docs`, `cyoda:design`, `cyoda:compute`, `cyoda:debug`) have no side effects and require no confirmation.

## Key Skill Behaviors

### cyoda:status

Reports the current Cyoda connection status in the conversation. Auto-invoked by Claude at session start and whenever connection context is relevant (e.g., before `cyoda:build`, after `cyoda:login`).

Uses dynamic context injection to read `.cyoda/config`:
```
!`jq . .cyoda/config 2>/dev/null || echo '{"endpoint":"none"}'`
```

Then calls the version/health endpoint and reports:
- `Connected to Local cyoda-go — v1.4.2` (local instance)
- `Connected to Cyoda Cloud — v2.1.0 [PRODUCTION]` (cloud, with prominent production marker)
- `Not connected — run /cyoda:setup to get started` (no config or unreachable)

**Monitor**: `monitors/monitors.json` runs a background command that watches `.cyoda/config` for changes. When the file changes (e.g., after `cyoda:login` or `cyoda:setup`), it notifies Claude with the new connection status automatically — no need for the user to re-invoke.

**Status line**: During implementation, explore using Claude Code's status line configuration (`subagentStatusLine` in plugin `settings.json`) for persistent header display of connection state.

### cyoda:docs

Uses dynamic context injection to check for local cyoda CLI at invocation time:

```
!`which cyoda 2>/dev/null && cyoda help 2>/dev/null | head -50 || echo "CYODA_CLI_NOT_INSTALLED"`
```

**Behavior:**
1. If cyoda CLI is not installed: asks the user whether they want to install it locally — local docs are version-specific and more accurate for API-level questions. If yes, delegates to `cyoda:setup` (local mode), then retries. If no, falls back to web docs (noting they reflect the latest, possibly different version).
2. If cyoda CLI is installed: uses `cyoda help` output as the primary source. Fetches web docs for anything not covered locally.
3. Always synthesizes a direct answer to the user's question — never dumps raw help output.

This skill is callable by other skills (e.g., `cyoda:build` delegates here when it needs API details) and also useful as a standalone `/cyoda:docs` command.

### cyoda:design

Two phases:

**Phase 1 — Orientation** (triggered when newcomer detected, i.e., no prior Cyoda context):
- Explain Cyoda as an EDBMS: entities are durable state machines, not rows
- Core philosophy: transitions as the unit of change, immutable revisions, events drive transitions
- Explain states, transitions, criteria, processors
- Clarify that compute nodes are optional — many workflows need no external processors

**Phase 2 — Domain brainstorm** (one question at a time):
- What domain objects have an independent lifecycle? → entities
- What states does each entity move through?
- What triggers each transition? (manual, time-based, message-based, automatic)
- Do any transitions need custom logic? → compute nodes (presented as optional)
- What does the schema look like? (discover mode for prototyping — schema evolves automatically, can switch to lock later; lock mode for production — schema fixed, mismatches rejected)

Output: a structured app design that feeds into `cyoda:build`.

### cyoda:build

Incremental build loop — supports both new additions and modifications to existing configs (adding states, transitions, criteria, changing schema mode):

1. **Inspect**: query the running Cyoda instance (`GET /api/model/*`) to show what already exists. If no instance is reachable, prompt the user to run `cyoda:setup` first.
2. **Brainstorm**: ask what to add or change next — one increment at a time (new entity, new state, new transition, schema lock, etc.)
3. **Clarify**: show the proposed JSON config, confirm with user before registering
4. **Register**: run `cyoda help models` + `cyoda help workflows` first to derive the correct API sequence (create model → import workflow → lock), then execute. The skill carries only conceptual descriptions of each sub-step — exact endpoints come from `cyoda help` at runtime. Requires `Bash(cyoda *)` in `allowed-tools`.
5. **Verify**: prompt to run `cyoda:test`, show the current entity/workflow state
6. **Loop**: back to step 2 for the next increment

Requires `allowed-tools: Bash(curl *)` for REST API calls and `Bash(cyoda *)` to run `cyoda help` in Step 4.

Handles the full lifecycle: create → evolve → lock. This also covers the hello world / quickstart path — the user starts the loop and the first increment is simply the minimal entity + workflow.

### cyoda:compute

Guides implementation of compute nodes (external gRPC processors), language-agnostic:

- gRPC connection lifecycle: join handshake (`CalculationMemberJoinEvent` → `CalculationMemberGreetEvent`), keep-alive, reconnection with exponential backoff
- Tag-based routing: how tags on workflow processors/criteria map to compute node registration tags
- Processor implementation pattern: receive `EntityProcessorCalculationRequest`, process, respond with `requestId` + `entityId`
- Criteria implementation pattern: receive `EntityCriteriaCalculationRequest`, return boolean
- Production requirements: idempotency via `requestId`, thread safety, timeout handling (default 60s)
- Points to `cyoda:docs` for current schema details and JSON Schema files from the docs repo

Compute nodes are always presented as optional — many Cyoda workflows need no external processors.

### cyoda:test

Runs in a forked subagent (`context: fork`) to avoid polluting the main conversation context.

Supports two modes:
- **Guided**: generates curl commands and test scripts the user can run and reuse
- **Automated**: executes tests directly against the running Cyoda instance when available

Test coverage: create entity, trigger manual transition, verify state, check transition history (point-in-time), test automatic transitions, verify processor invocation.

### cyoda:debug

Systematic diagnosis and observation of Cyoda entities and workflows. Two modes of use:

**Debugging** — fix problems:
- Failed transitions: check criteria evaluation, state machine config, processor errors
- Processor errors: gRPC connectivity, timeout, response format, tag routing
- Entity not found / wrong state: query entity history, check workflow definition
- Schema rejection: discover vs lock mode, type widening rules
- Connectivity: local vs cloud endpoint, auth token validity

**Observation** — understand what happened (audit, compliance, investigation):
- Query entity transition history: full lifecycle of a specific entity
- Point-in-time state lookup: "what state was entity X in at time T?"
- Browse audit trail: which transitions fired, which processors ran, in what order
- Uses Cyoda's history and point-in-time APIs directly

Both modes use the same underlying Cyoda APIs. Delegates to `cyoda:docs` for API reference when needed.

### cyoda:login

Obtains a JWT token via OAuth 2.0 client credentials flow and writes connection config to `.cyoda/config`.

**Flow:**
1. Ask: "Is this a development or production environment?"
2. If **development**: proceed, write config with `"env": "development"`
3. If **production**: show warning — *"Storing production credentials in a local file is a security risk. This file will be gitignored but remains on disk in plain text. Do you accept this risk?"* — require explicit `yes` before proceeding, write `"env": "production"`
4. Explain M2M credentials, then collect them:
   - Explain: *"`client_id` and `client_secret` are machine-to-machine (M2M) credentials that identify your application or service to Cyoda — not a personal login. They're used by automated pipelines, compute nodes, and any service calling the Cyoda API."*
   - Ask: "Do you already have a `client_id` and `client_secret`?"
     - If yes: collect them and proceed.
     - If no: direct to Cyoda AI Studio at https://ai.cyoda.net/ — ask it to "create a technical user". Return once credentials are available.
   - **Post-redeploy note**: if the environment was recently redeployed, technical users may have been deleted — credentials that previously worked may fail. In that case, recreate the technical user in AI Studio.
5. Call OAuth token endpoint, obtain JWT
6. Merge `token` and `env` into `.cyoda/config` using `jq` (preserves existing `endpoint`)
7. Add `.cyoda/config` and `.cyoda/` to `.gitignore` if not already present

Skills making API calls (`cyoda:build`, `cyoda:test`, `cyoda:migrate`) read credentials via dynamic context injection at invocation time:
```
!`jq . .cyoda/config 2>/dev/null || echo '{"endpoint":"none"}'`
```
If `endpoint` is absent or `"none"`, the skill prompts the user to run `cyoda:setup` first. If `token` is absent when a cloud instance is required, the skill prompts to run `cyoda:login`.

When `.env` equals `"production"`, all API-calling skills display a visible reminder: *"Operating against a production Cyoda instance."* `cyoda:build` adds an extra confirmation step before registering any changes.

**Local cyoda-go**: no token needed (mock auth). `cyoda:setup` (local mode) writes `{"endpoint": "http://localhost:8080", "env": "development"}` to `.cyoda/config`.

### cyoda:setup

Two modes, selected at invocation:

**Local (cyoda-go):**
1. Check if already installed (dynamic injection: `which cyoda`)
2. Install if needed: attempt `brew tap cyoda-platform/cyoda-go` then `brew install cyoda`. If either command fails for any reason (permissions, network, Homebrew not found), do NOT attempt to diagnose or fix Homebrew — immediately show the exact commands and ask the user to run them manually in their terminal. Wait for confirmation before continuing.
3. Initialize: `cyoda init` (SQLite by default)
4. Start: `cyoda` (foreground; user opens new terminal for subsequent commands)
5. Verify: `curl http://localhost:8080/readyz`
6. Write `{"endpoint": "http://localhost:8080", "env": "development"}` to `.cyoda/config`
7. Gitignore `.cyoda/config` and `.cyoda/`
8. Confirm: mock auth is active — `cyoda:login` not needed for local

**Cloud:**
1. Check for existing Cyoda Cloud account; if none, direct to Cyoda AI Studio at https://ai.cyoda.net/ — the user can prompt it: "create a new environment", "list my environments", or "redeploy environment X". The response provides the endpoint URL.
2. Collect endpoint URL (format: `https://client-<hash>-<env>.eu.cyoda.net`); probe reachability before writing config
3. Write `{"endpoint": "<url>"}` to `.cyoda/config`
4. Gitignore `.cyoda/config` and `.cyoda/`
5. Prompt user to run `cyoda:login` to complete auth
6. Verify connectivity with a test API call after login

### cyoda:migrate

Lift-and-shift from local cyoda-go to Cyoda Cloud:

1. Export all entity models, **JSON Schema (field definitions)**, and workflow configs from local instance (GET endpoints). Schema export uses `GET /api/model/export/JSON_SCHEMA/{entity}/{version}`. Both schema and workflow must be exported per entity.
2. Invoke `cyoda:setup` (cloud mode) — account setup, endpoint, auth
3. Import models, schemas, and workflows to cloud instance (POST endpoints)
4. Run `cyoda:test` against the cloud endpoint to verify behavior matches local
5. Guide the user to update their application's Cyoda endpoint and auth config

Since Cyoda Cloud and cyoda-go share the same REST/gRPC API surface, migration is purely a configuration change — no code changes required.

### cyoda:app

Newcomer orchestrator. Walks the user through the full journey by sequencing the other skills:

1. Orient to Cyoda philosophy (inline, brief)
2. Invoke `cyoda:design` for domain brainstorm
3. **Check existing instance first**: invoke `cyoda:status` before asking local vs cloud. If already connected, confirm whether to use that environment. Only ask local/cloud if not connected.
4. Invoke `cyoda:setup` (local or cloud, user's choice) if not already configured
5. Invoke `cyoda:build` for incremental implementation
6. Invoke `cyoda:test` for smoke testing
7. Offer `cyoda:migrate` if user wants to move to cloud

Experienced users can skip this and invoke individual skills directly.

## Authentication and Session Config

Connection config is stored in a project-level `.cyoda/config` file (always gitignored):

```json
{
  "endpoint": "http://localhost:8080",
  "token": "eyJ...",
  "env": "development"
}
```

`token` is absent for local cyoda-go (mock auth, no token needed). `env` defaults to `"development"` when absent.

Skills read this file via dynamic context injection at invocation time using `jq`. If the file is missing or `token` is absent when a cloud instance is required, the skill prompts to run `cyoda:login`.

**Production safety rule**: `"env": "production"` is only written after explicit user confirmation. When `.env` equals `"production"`, all API-calling skills display a production reminder and `cyoda:build` requires confirmation before registering changes.

## Documentation Strategy

No Cyoda documentation is embedded in skill bodies. Instead:
- `cyoda:docs` fetches docs dynamically (local CLI preferred, web fallback)
- `cyoda:build` runs `cyoda help` directly in Step 4 — proactively before any curl, not as fallback
- Other skills delegate to `cyoda:docs` for API details
- Skills reference supporting files in their directory for examples and templates

This ensures docs stay accurate for the installed Cyoda version and never go stale in the plugin code.

## Cyoda Philosophy Alignment

All skills embed these principles:

- **Entities are durable state machines** — not rows to be updated in place
- **Transitions are the unit of change** — nothing is overwritten; every transition produces a new revision
- **Compute nodes are optional** — many workflows need no external processors; always present this as a choice
- **Same semantics across tiers** — local cyoda-go and Cyoda Cloud share identical API surfaces; lift-and-shift requires no code changes
- **Discover mode for prototyping, lock for production** — schema management is an explicit phase transition

## Scenario Validation

**Scenario 1: Chess app, JS SPA + Cyoda Cloud, no prior knowledge**
- `cyoda:app` or `cyoda:design` (auto-invoked) orients user to Cyoda philosophy
- `cyoda:design` elicits: Room, Game, Move, Player entities with lifecycle workflows
- `cyoda:setup` (cloud mode) handles account + connection (no local install needed)
- `cyoda:build` generates and registers workflow configs incrementally
- `cyoda:docs` answers "how do I call the REST API from JavaScript?"

**Scenario 2: Risk management system, query submissions by time period**
- `cyoda:docs` (auto-invoked) checks local cyoda CLI, synthesizes search API answer
- Returns: correct endpoint, `createdAt` range filter, sync vs async search guidance

**Scenario 3: Hello world on cyoda-go → lift-and-shift to cloud**
- `cyoda:setup` (local): install, init, start, health check
- `cyoda:build`: first increment = one entity + draft→submitted workflow
- `cyoda:test`: smoke test
- `cyoda:migrate`: export → cloud setup → import → test on cloud

## Supporting Files Per Skill

Skills with non-trivial supporting files (others have only `evaluations/`):

| Skill | Supporting files |
|---|---|
| `cyoda:design` | `resources/patterns.md` — common workflow patterns (approval flow, saga, scheduled retry, auto-transition cascade, multi-workflow models) |
| `cyoda:build` | `templates/workflow.json`, `templates/entity-model.json`, `examples/` |
| `cyoda:compute` | `resources/grpc-patterns.md`, `examples/processor.md`, `examples/criteria.md` |
| `cyoda:test` | `templates/smoke-test.sh` |
| `cyoda:migrate` | `templates/migration-checklist.md` |

## Evaluations

Each skill includes an `evaluations/` directory with 3+ JSON eval files covering:
- Happy path
- Edge case or anti-pattern
- Error/failure scenario

## References

- Cyoda docs: https://docs.cyoda.net/
- OpenAPI: https://docs.cyoda.net/openapi/openapi.json
- gRPC schemas: https://github.com/Cyoda-platform/cyoda-docs/tree/main/src/schemas
- cyoda-go repo: https://github.com/cyoda-platform/cyoda-go
- Skills guide: https://code.claude.com/docs/en/skills.md
- Plugins guide: https://code.claude.com/docs/en/plugins
