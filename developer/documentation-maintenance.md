# Documentation Maintenance

Docs are part of the product. They describe operational contracts, not just implementation notes.

## Source And Build Files

| File or folder | Purpose |
| --- | --- |
| `mkdocs.yml` | MkDocs Material configuration and navigation. |
| `docs/` | Documentation source. |
| `docs/scripts/generate_config_docs.ps1` | PowerShell wrapper for generated config docs. |
| `docs/scripts/generate_config_docs.py` | Generates config reference and flag pages. |
| `docs/scripts/check_docs.ps1` | Regenerates config docs and runs strict MkDocs build. |
| `site/` | Generated output; do not edit by hand. |

## Audience Layout

Use these prefixes:

- `/user/` for operator-facing and workflow-first documentation.
- `/developer/` for maintainer-facing internals and change guidance.
- `/configuration/` for shared config reference.
- `/operations/` for detailed runbooks.
- `/integrations/` for external and local API contracts.
- `/database/` for schema notes and config table details.
- `/architecture/` for shared system design.

## When To Update Docs

Update docs in the same task when changing:

- sync runtime behaviour
- config columns, defaults, validation, or generated templates
- REST endpoints, payloads, response fields, or error behaviour
- dashboard workflows or browser local-storage keys
- launch scripts, ports, logs, or process layout
- object-search indexing, sidecar routes, or local storage paths
- operational runbooks or troubleshooting procedures
- user-facing dashboard layouts that should refresh screenshot-backed pages

## Config Item Template

| Field | Required content |
| --- | --- |
| Name | The exact flag, parameter, storage key, or setting name. |
| Storage location | SQL table/column, browser key, file path, process parameter, or environment location. |
| Valid values | Accepted values and rejected values where known. |
| Default | Code default, generated-template default, or observed default. |
| Code paths affected | Scripts, modules, routes, and dashboard files. |
| Operational risk | What can break or leak if changed incorrectly. |
| Safe change procedure | Practical steps an operator can follow. |
| Confidence | Confirmed, inferred, or uncertain. |

## Build Check

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\check_docs.ps1
```

This regenerates generated config docs before building. If generated files change, review them before committing.

## Style Notes

- Prefer practical steps over abstract summaries.
- Keep legacy knowledge unless it has been confirmed obsolete.
- Use Mermaid diagrams when they clarify flow or responsibility.
- Mark uncertain conclusions explicitly.
- Keep links relative and valid under `use_directory_urls: false`.
- Do not edit generated `site/` files directly.
