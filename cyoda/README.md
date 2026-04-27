# Cyoda Plugin for Claude Code

Helps you build applications on [Cyoda](https://cyoda-docs-feature-cyoda-go-init.surge.sh/) — an Entity Database Management System (EDBMS).

## Skills

| Skill | Purpose |
|---|---|
| `/cyoda:app` | Start here if you're new — walks the full journey |
| `/cyoda:setup` | Install cyoda-go locally or connect to Cyoda Cloud |
| `/cyoda:login` | Authenticate to Cyoda Cloud (obtain JWT) |
| `/cyoda:design` | Brainstorm entities and workflows for your app |
| `/cyoda:build` | Incrementally build and register entity models and workflows |
| `/cyoda:compute` | Implement compute node processors via gRPC |
| `/cyoda:test` | Smoke-test your running Cyoda instance |
| `/cyoda:debug` | Diagnose failures and browse entity history |
| `/cyoda:migrate` | Lift-and-shift from local cyoda-go to Cyoda Cloud |
| `/cyoda:docs` | Look up Cyoda documentation |
| `/cyoda:status` | Check connection status |

## Connection Config

Skills share connection state via `.cyoda/config` (always gitignored):

```
CYODA_ENDPOINT=http://localhost:8080
CYODA_TOKEN=eyJ...
CYODA_ENV=development
```

Run `/cyoda:setup` then `/cyoda:login` to populate this file.
