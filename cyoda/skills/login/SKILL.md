---
name: login
description: Authenticate to Cyoda Cloud using OAuth 2.0 client credentials. Obtains a JWT token and saves it to .cyoda/config. Includes production safety guard requiring explicit confirmation before storing production credentials.
allowed-tools: Bash(curl *) Bash(cat *) Bash(grep *) Bash(tee *) Bash(echo *) Bash(jq *)
---

## Cyoda Login

Reading current endpoint:
```!
jq -r '.endpoint // "none"' .cyoda/config 2>/dev/null || echo "none"
```

If endpoint is `none`: *"No Cyoda endpoint configured. Run `/cyoda:setup` first."* Stop.

**Step 1 — Confirm environment type:**

Ask: *"Is this a development or production environment?"*

If **production**: display this warning and require explicit confirmation:

> ⚠️ **Security warning**: You are about to store production credentials in `.cyoda/config` on disk. This file will be gitignored, but it remains in plain text on your filesystem. Anyone with access to this machine can read it.
>
> Do you accept this risk? (yes/no)

If user answers anything other than `yes`: stop. Do not write any credentials.

**Step 2 — Explain and collect credentials:**

Explain what these credentials are:

> "`client_id` and `client_secret` are **machine-to-machine (M2M) credentials** — they identify your application or service to Cyoda, not a personal user account. They are used by automated pipelines, compute nodes, and any service calling the Cyoda API."

Ask: *"Do you already have a `client_id` and `client_secret`?"*

- **If yes**: collect them and proceed.
- **If no**: direct the user to [Cyoda AI Studio](https://ai.cyoda.net/) — ask it to "create a technical user". Return once credentials are available.

**Post-redeploy note**: if the environment was recently redeployed, existing technical users may have been deleted. If authentication fails and the environment was redeployed, recreate the technical user in AI Studio before retrying.

Ask for `client_id` and `client_secret` separately, one at a time. Do not echo the secret back in the conversation.

**Step 3 — Obtain JWT token:**

```bash
ENDPOINT=$(jq -r '.endpoint' .cyoda/config)
TOKEN_RESPONSE=$(curl -sf -X POST "${ENDPOINT%/}/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")
echo "$TOKEN_RESPONSE"
```

Note: Verify the exact OAuth token endpoint path against the Cyoda OpenAPI spec. Common paths: `/oauth/token`, `/auth/token`, `/api/auth/token`.

If the curl fails or returns an error: show the error and stop. Do not write partial credentials.

**Step 4 — Extract and write token:**

```bash
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
ENV_VALUE="development"  # or "production" based on Step 1

# Update .cyoda/config preserving endpoint
jq --arg token "$TOKEN" --arg env "$ENV_VALUE" \
  '. + {"token": $token, "env": $env}' .cyoda/config > .cyoda/config.tmp
mv .cyoda/config.tmp .cyoda/config

grep -qxF '.cyoda/config' .gitignore 2>/dev/null || echo '.cyoda/config' >> .gitignore
grep -qxF '.cyoda/' .gitignore 2>/dev/null || echo '.cyoda/' >> .gitignore
```

**Step 5 — Confirm:**

Report: *"Authenticated successfully. Token written to `.cyoda/config`. Run `/cyoda:status` to verify the connection."*

If `.env` equals `production`: add prominent reminder — *"⚠️ You are now connected to a PRODUCTION instance. Changes made via `/cyoda:build` will affect live data."*
