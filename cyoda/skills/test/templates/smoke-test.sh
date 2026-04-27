#!/usr/bin/env bash
# Cyoda smoke test — edit ENTITY_NAME, MODEL_VERSION, and TRANSITION_NAME
set -euo pipefail

ENDPOINT="${CYODA_ENDPOINT:-http://localhost:8080}"
TOKEN="${CYODA_TOKEN:-}"
AUTH_HEADER=$([ -n "$TOKEN" ] && echo "-H 'Authorization: Bearer $TOKEN'" || echo "")
ENTITY_NAME="${ENTITY_NAME:-my-entity}"
MODEL_VERSION="${MODEL_VERSION:-1}"
TRANSITION_NAME="${TRANSITION_NAME:-submit}"

echo "=== Cyoda Smoke Test ==="
echo "Endpoint: $ENDPOINT"
echo "Entity: $ENTITY_NAME v$MODEL_VERSION"
echo ""

# 1. Create entity
echo "--- Creating entity..."
RESPONSE=$(curl -sf -X POST $AUTH_HEADER \
  -H 'Content-Type: application/json' \
  -d '{"test": true}' \
  "${ENDPOINT}/api/entity/JSON/${ENTITY_NAME}/${MODEL_VERSION}")
ENTITY_ID=$(echo "$RESPONSE" | grep -o '"entityIds":\["[^"]*"' | cut -d'"' -f4)
echo "Created entity: $ENTITY_ID"

# 2. Verify initial state
echo "--- Checking initial state..."
STATE=$(curl -sf $AUTH_HEADER "${ENDPOINT}/api/entity/${ENTITY_ID}" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
echo "Initial state: $STATE"

# 3. Trigger transition
echo "--- Triggering transition: $TRANSITION_NAME..."
curl -sf -X PUT $AUTH_HEADER "${ENDPOINT}/api/entity/JSON/${ENTITY_ID}/${TRANSITION_NAME}"
echo "Transition triggered"

# 4. Verify new state
echo "--- Checking new state..."
NEW_STATE=$(curl -sf $AUTH_HEADER "${ENDPOINT}/api/entity/${ENTITY_ID}" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
echo "New state: $NEW_STATE"

echo ""
echo "=== PASS ==="
