# SQL Editor

## Purpose

`SQL Editor` is a dashboard page for drafting SQL and running local lint checks before you execute or migrate script changes elsewhere.

It does not execute SQL statements. It is a write-and-review surface with object-definition loading and lint feedback.

## How to open it

1. Open the page directly from navigation: `Engineering` -> `SQL Editor`.
2. Or open `Ctrl+K` command palette, select an indexed database object, and use the detail panel dropdown action `Open in SQL Editor`.

When opened from command palette, SQL Editor receives object context (server, database, schema, object name, object type) and attempts to load the indexed `definition` text from local object search.

## Lint checks currently included

SQL Editor now calls API lint endpoints:

- `GET /api/sql/lint/providers`
- `POST /api/sql/lint`

Provider behavior:

- prefers `SQLFluff` (open source) when the `sqlfluff` executable is available on the host
- falls back to built-in heuristic checks when SQLFluff is not installed

Built-in fallback checks include:

- unclosed string literals
- unclosed block comments
- unmatched opening or closing parentheses
- `SELECT *` usage warnings
- `DELETE FROM` without `WHERE` warnings
- `UPDATE` without `WHERE` warnings
- `TRUNCATE TABLE` warnings
- `DROP` object warnings

Auto-lint can be toggled from the editor header.

## SQLFluff installation (optional but recommended)

Install SQLFluff on the workstation hosting the local API:

```powershell
pip install sqlfluff
```

Then verify:

```powershell
sqlfluff --version
```

When available, SQL Editor automatically uses SQLFluff via API lint calls.

## Operational risk and safe procedure

### Risk

- lint checks are heuristic and do not replace SQL Server parser validation
- a clean lint result does not guarantee runtime safety
- warning checks for missing `WHERE` can still be intentional in set-based maintenance scripts

### Safe procedure

1. Load the object definition in SQL Editor when available.
2. Run lint and resolve `error` findings first.
3. Review each `warning` and confirm intent.
4. Validate final SQL in a non-production environment using normal deployment workflow.

## Confidence

- confirmed:
  SQL Editor uses indexed object metadata from the local object-search endpoint when launched with `objectId`.
- uncertain:
  lint rules are intentionally lightweight and do not model full T-SQL grammar.
