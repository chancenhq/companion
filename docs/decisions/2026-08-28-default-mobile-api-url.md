# Point mobile app at Companion production API

## Context

Upstream Sure defaults the mobile API base URL to `https://demo.sure.am`. Companion's `mobile/lib/services/api_config.dart` defaults to `https://companion-prod.chancen.tech`.

## Decision

Use the Companion production API URL as the mobile app default.

## Consequence

Fresh installs target the Chancen Companion backend without a manual backend URL change. Debug builds can still change the backend URL through debug-only settings.
