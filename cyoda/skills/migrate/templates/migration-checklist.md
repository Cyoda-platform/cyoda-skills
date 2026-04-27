# Cyoda Lift-and-Shift Checklist

## Pre-Migration

- [ ] Local cyoda-go instance is running (`cyoda health`)
- [ ] Cyoda Cloud account exists
- [ ] All entity models and workflows working locally (run `/cyoda:test` to verify)
- [ ] Application code does NOT hardcode `localhost:8080` — uses `CYODA_ENDPOINT` from config

## Export from Local

- [ ] List all entity models: `GET /api/model`
- [ ] Export each workflow: `GET /api/model/{name}/{version}/workflow`
- [ ] Save exported configs to `migration/` directory

## Cyoda Cloud Setup

- [ ] Run `/cyoda:setup` (cloud mode) — endpoint configured
- [ ] Run `/cyoda:login` — JWT token obtained
- [ ] Run `/cyoda:status` — confirm cloud connection

## Import to Cloud

- [ ] Import each workflow: `POST /api/model/{name}/{version}/workflow/import`
- [ ] Verify models exist in cloud: `GET /api/model`

## Verification

- [ ] Run `/cyoda:test` against cloud endpoint
- [ ] All smoke tests pass
- [ ] Point-in-time queries work

## App Config Update

- [ ] Update application environment config to point to cloud endpoint
- [ ] Update auth token handling in application
- [ ] Deploy updated application
