# Use invitations and default family for mobile signup

## Context

Upstream Sure mobile signup creates a new family for the user. Companion's API signup and SSO account creation paths in `app/controllers/api/v1/auth_controller.rb` include invitation/default-family/default-role handling.

## Decision

Assign mobile signup and SSO-created users through Companion invitation/default-family rules instead of always creating a standalone family.

## Consequence

New mobile members can land in the intended Companion family/role context. Signup behavior depends on invitation and default-family configuration being correct.
