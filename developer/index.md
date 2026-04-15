# Developer Documentation

This section is for maintainers changing SQL Cockpit code, configuration behaviour, REST contracts, dashboard pages, or documentation generation.

Developer URLs live under:

```text
/developer/
```

The shared reference sections remain available under `/configuration/`, `/database/`, `/integrations/`, `/architecture/`, and `/operations/`.

## Start Here

- [System Map](system-map.md): how the PowerShell, Node, Next.js, SQL, docs, and object-search parts fit together.
- [Local Development](local-development.md): build, run, and validate the repo.
- [Cross-Platform Service Strategy](cross-platform-service-strategy.md): Windows-first today, plus the Linux/macOS service-host rollout plan.
- [Data Model And Runtime Contracts](data-model-and-runtime-contracts.md): config tables, state tables, logs, and safe change rules.
- [REST And Dashboard Internals](rest-and-dashboard-internals.md): route-to-operation mapping and browser state.
- [Documentation Maintenance](documentation-maintenance.md): how to keep docs aligned with code and config changes.
- [Docs Screenshots](docs-screenshots.md): automated capture workflow for app screenshots in the docs.

## Maintainer Rules

1. Treat database config tables as public operational interface.
2. Update docs in the same task as behaviour changes.
3. Document storage location, valid values, defaults, affected paths, risk, and safe change procedure for new settings.
4. Mark inferred or uncertain conclusions explicitly.
5. Preserve legacy knowledge unless it has been confirmed obsolete.
6. Keep the MkDocs site buildable.
