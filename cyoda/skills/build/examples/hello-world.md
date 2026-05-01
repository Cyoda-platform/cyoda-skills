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

> **Stay in discover mode during development.** The schema evolves automatically as you post entities. Only consider locking the schema when you are confident all fields are known and you are moving to production.
