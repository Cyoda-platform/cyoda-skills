# Compute Node Processor Implementation

## What you receive

`EntityProcessorCalculationRequest`:
- `requestId` — deduplicate with this
- `entityId` — ID of the entity being processed
- `entityData` — current entity JSON payload
- `transitionName` — the transition that triggered this processor

## What you return

`EntityProcessorCalculationResponse`:
- `requestId` — echo the same requestId
- `entityId` — echo the same entityId
- `entityData` — modified entity JSON (or unchanged if no modification needed)
- `success` — boolean

## Pseudocode (language-agnostic)

```
function handleProcessorRequest(request):
  if alreadyProcessed(request.requestId):
    return cachedResponse(request.requestId)

  entity = parseJSON(request.entityData)

  // your business logic here
  entity.processedAt = now()
  entity.status = "enriched"

  response = {
    requestId: request.requestId,
    entityId: request.entityId,
    entityData: toJSON(entity),
    success: true
  }

  cacheResponse(request.requestId, response)
  return response
```

## Timeout

Complete the response within 60 seconds (default). For long operations, use async processing and return a "processing started" response, then trigger a transition when complete.
