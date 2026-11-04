# Companion Docker E2E

This lane builds the production `Dockerfile`, starts Companion with PostgreSQL
and Redis, and exercises the running application over HTTP. It intentionally
uses an invitation-assigned country rather than testing country selection: the
family country is the source of truth for a member's country.

Requirements:

- Docker with Compose
- Bats
- `curl`
- `jq`

Run locally from the repository root:

```sh
bats --timing test/e2e/companion.bats
```

The suite cleans up its Compose services and volumes after the run. The
invitation seed is deliberately created inside the application container so
the test exercises the same Rails models and validations as production.
