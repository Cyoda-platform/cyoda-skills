# Cyoda Compute Node gRPC Patterns

## Connection Lifecycle

All compute nodes connect via a persistent bidirectional gRPC stream to `CloudEventsService.startStreaming`.

### 1. Join Handshake

Send `CalculationMemberJoinEvent` with your tags:
```json
{
  "type": "CalculationMemberJoinEvent",
  "tags": ["my-processor-tag", "environment-tag"]
}
```

Receive `CalculationMemberGreetEvent` with your assigned `memberId`. Store this ID.

### 2. Keep-Alive

Respond to periodic heartbeat probes within the configured timeout (default 60s). Failure to respond causes disconnection.

### 3. Reconnection

Implement exponential backoff on disconnection:
- Attempt 1: wait 1s
- Attempt 2: wait 2s
- Attempt 3: wait 4s
- Cap at 60s

On reconnect, send `CalculationMemberJoinEvent` again (new `memberId` will be assigned).

## Tag-Based Routing

The platform routes requests only to members whose registered tags form a **superset** of the tags configured on the workflow processor/criterion.

Example: if workflow processor has tags `["payment", "eu"]`, your compute node must register with at least `["payment", "eu"]` (plus any additional tags you want).

Tags are case-insensitive.

## Authentication

Include a JWT bearer token in gRPC metadata headers:
```
Authorization: Bearer eyJ...
```

## Thread Safety

All `StreamObserver.onNext()` calls must be synchronized. The gRPC stream is not thread-safe.

## Idempotency

Use the `requestId` field in every request to deduplicate retries. If you receive a request with a `requestId` you've already processed, return the same response.
