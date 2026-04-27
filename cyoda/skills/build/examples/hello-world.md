# Hello World — Minimal Cyoda App

The minimal first increment: one entity (`hello`) with a two-state workflow.

## Workflow config

```json
{
  "workflows": [
    {
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
    }
  ]
}
```

## Register

```bash
curl -X POST http://localhost:8080/api/model/hello/1/workflow/import \
  -H 'Content-Type: application/json' \
  -d @workflow.json
```

## Create entity

```bash
curl -X POST http://localhost:8080/api/entity/JSON/hello/1 \
  -H 'Content-Type: application/json' \
  -d '{"message": "Hello, Cyoda!"}'
```

## Trigger transition

```bash
curl -X PUT http://localhost:8080/api/entity/JSON/${ENTITY_ID}/submit
```
