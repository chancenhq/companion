# Auto-link Google SSO by verified email

## Context

Upstream Sure sends unlinked mobile Google/OIDC identities into account-linking onboarding. Companion's `app/controllers/sessions_controller.rb` auto-links the identity when the provider email matches an existing user, with a code comment noting that Google has verified the email.

## Decision

Allow verified Google/OIDC email matches to create the missing `OidcIdentity` and continue mobile sign-in without a separate password-linking prompt. MFA-enabled users are rejected from this auto-link path.

## Consequence

Returning members with a matching verified Google email can sign in through Google without a manual link step. The account-binding trust decision depends on the provider's verified email claim.
