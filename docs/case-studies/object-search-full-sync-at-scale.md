# Object Search Full Sync at Scale

This case study documents a full Object Search sync run and how to interpret outcomes for large metadata estates.

## Scenario

- A team needs to bootstrap or rebuild local object-search index data.
- A source database has high object volume and rich child metadata.
- Operators need clear expectations for timing, logs, and recovery behavior.

## Example run outcome

The sample full sync produced the following totals for `firebird/SOURCE_DATABASE`:

| Metric | Value | Meaning |
| --- | ---: | --- |
| Base objects | 8,783 | Parent SQL objects (tables, views, procedures, functions, triggers, synonyms). |
| Columns | 86,592 | Table and view column metadata. |
| Parameters | 5,185 | Procedure and function parameters. |
| Dependency rows | 19,831 | Object-reference relationships. |
| Indexes | 322 | Index metadata linked to parent table context. |
| Constraints | 7,328 | Constraint metadata such as PK/FK/unique/check/default. |
| Searchable documents | 103,025 | Final Lucene document set across parent and child metadata. |

## Runtime phases

```mermaid
flowchart LR
    A[Read SQL catalog metadata] --> B[Build normalized documents]
    B --> C[Upload batches to Lucene service]
    C --> D[Delete stale ids from prior manifest]
    D --> E[Write new manifest]
```

## How to interpret performance

- Fast catalog-read steps with slower document-build time usually indicate PowerShell-side normalization cost, not SQL metadata retrieval bottlenecks.
- Document totals significantly larger than base-object counts are expected because columns, constraints, and indexes become searchable entries.
- Full mode replaces scope content safely by uploading fresh documents before stale deletes.

## Failure handling and recovery

1. If upload returns `400 Bad Request`, batching can split down to isolate failing payloads.
2. Spool artifacts (`documents.json`, `checkpoint.json`) allow resume behavior for interrupted runs.
3. Completed source runs clear the spool directory after manifest write.
4. If local state is intentionally reset, stop the sidecar first, then clear `index`, `spool`, and `manifests`, and run full sync again.

## Safe change procedure

1. Confirm local sidecar health (`GET /api/object-search/health`).
2. Run one low-risk incremental sync first.
3. Validate search quality with exact-name and definition-text queries.
4. Run full sync for large sources only after baseline checks pass.
5. Confirm manifest write and stale-delete phases complete.

## Operational risks

- Local disk now stores searchable definitions and metadata.
- Child-object stale detection relies on manifest comparison.
- Sidecar runtime dependencies (`dotnet` or bundled executable) must be healthy for sync and query workflows.

## Related references

- [Object Search Operations](../operations/object-search.md)
- [Troubleshooting](../operations/troubleshooting.md)
- [Runbooks](../operations/runbooks.md)
