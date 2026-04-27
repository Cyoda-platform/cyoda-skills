# Common Cyoda Workflow Patterns

Reference this file when designing entity workflows. Present relevant patterns during the domain brainstorm.

## Approval Flow

Entity moves from submitted → under_review → approved/rejected. Manual transitions for review actions. Criteria guard the approval transition (e.g., reviewer must be assigned).

States: `draft` → `submitted` → `under_review` → `approved` | `rejected`
Key transitions: `submit` (manual), `assign` (manual), `approve` (manual + criteria), `reject` (manual)

## Scheduled Retry / Timeout

After entering a waiting state, automatically transition to `timed_out` after a delay if no response arrives.

Use a scheduled processor: `{ "type": "scheduled", "config": { "delayMs": 3600000, "transition": "timeout" } }`

## Auto-Transition Cascade

Entity auto-advances through several states as soon as criteria are met, without manual intervention. Useful for processing pipelines.

States: `received` → `validated` → `enriched` → `ready`
All transitions are automatic with criteria on each.

Safety: Cyoda limits cascades to 100 steps and 10 visits per state (CYODA_MAX_STATE_VISITS).

## Multi-Workflow Model

Entity participates in multiple independent workflows (e.g., a lifecycle workflow AND a compliance workflow). Platform evaluates active workflows in order, uses first whose criterion matches.

Use when: different aspects of an entity's lifecycle need independent state machines.

## Saga-Style Coordination

Multiple entities coordinate across a process. Each entity manages its own state; a coordinator entity tracks the overall saga state and triggers transitions on participants.

Note: Cyoda does not have built-in saga support — implement by having compute nodes create/transition related entities via REST API calls.

## External Event Trigger

Incoming external events (webhooks, messages) drive entity transitions. Register a message-based transition that fires when a CloudEvent of a specific type arrives.
