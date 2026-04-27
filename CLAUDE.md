# agent-skills

This repo contains the **Cyoda Claude Code plugin** — a set of skills that help developers build, test, and run applications on Cyoda.

Design specs (source of truth changed date): `docs/superpowers/specs/*`

## Off-limits

`_developer/` is private developer notes. **Never read or write files there.**

## Skill authoring

When creating or editing skills, invoke the `superpowers:writing-skills` skill first.

Each skill lives in its own directory under `skills/` with:
- `SKILL.md` — required frontmatter: `name`, `description`, and `disable-model-invocation: true` for skills with side effects
- `evaluations/` — 3+ JSON eval files covering happy path, edge case, and failure scenario
- Optional: `examples/`, `templates/`, `resources/`

Rules that are easy to get wrong:
- `SKILL.md` files stay under 500 lines — reference supporting files rather than embedding content inline
- Never embed Cyoda docs in skill bodies — `cyoda:docs` fetches them dynamically at runtime
- Skills with side effects (`setup`, `build`, `test`, `migrate`, `app`) must have `disable-model-invocation: true`

## References

- Cyoda docs: https://cyoda-docs-feature-cyoda-go-init.surge.sh/
- OpenAPI: https://github.com/Cyoda-platform/cyoda-docs/blob/main/public/openapi/openapi.json
- Plugins guide: https://code.claude.com/docs/en/plugins
- Skills guide: https://code.claude.com/docs/en/skills.md
