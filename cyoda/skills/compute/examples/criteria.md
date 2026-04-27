# Compute Node Criteria Implementation

## What you receive

`EntityCriteriaCalculationRequest`:
- `requestId` — deduplicate with this
- `entityId` — ID of the entity being evaluated
- `entityData` — current entity JSON payload
- `criteriaName` — the criteria being evaluated

## What you return

`EntityCriteriaCalculationResponse`:
- `requestId` — echo the same requestId
- `entityId` — echo the same entityId
- `result` — boolean (true = criteria met, transition may fire)

## Pseudocode

```
function handleCriteriaRequest(request):
  if alreadyEvaluated(request.requestId):
    return cachedResponse(request.requestId)

  entity = parseJSON(request.entityData)

  // your boolean logic here
  result = entity.amount > 1000 AND entity.currency == "EUR"

  return {
    requestId: request.requestId,
    entityId: request.entityId,
    result: result
  }
```
