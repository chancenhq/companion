# Hide mobile debug login controls in release builds

## Context

The upstream Sure mobile login screen exposes backend URL/settings controls and an API-key login button in the normal UI. In Companion, these controls are wrapped in `kDebugMode` in `mobile/lib/screens/login_screen.dart`.

## Decision

Keep backend settings and visible API-key login controls available only in Flutter debug builds.

## Consequence

Release users should not be able to reach the debug API-key dialog from the normal login screen. This does not remove the persisted API-key auth mode; restoring a previously saved API key in release remains a separate security-backlog finding.
