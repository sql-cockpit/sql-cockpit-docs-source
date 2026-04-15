from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DOCS_ROOT = REPO_ROOT / "docs"
FLAGS_ROOT = DOCS_ROOT / "configuration" / "flags"
SCRIPT_PATH = REPO_ROOT / "Sync-ConfiguredSqlTable.ps1"

CONFIRMED_ITEMS = [
    "SyncId",
    "SyncName",
    "IsEnabled",
    "SyncMode",
    "SourceServer",
    "SourceDatabase",
    "SourceSchema",
    "SourceTable",
    "SourceAuthMode",
    "SourceUsername",
    "SourcePassword",
    "DestinationServer",
    "DestinationDatabase",
    "DestinationSchema",
    "DestinationTable",
    "DestinationAuthMode",
    "DestinationUsername",
    "DestinationPassword",
    "CommandTimeoutSeconds",
    "BatchSize",
    "RetryCount",
    "RetryDelaySeconds",
    "KeyColumnsCsv",
    "ColumnsCsv",
    "ExcludeColumnsCsv",
    "WatermarkColumn",
    "WatermarkType",
    "FullScanAllow",
    "InsertOnly",
    "MaxBatchesPerRun",
    "AutoCreateDestinationTable",
    "CreatePrimaryKeyOnAutoCreate",
    "ValidateDestinationSchema",
    "SourceWhereClause",
    "PreSyncSql",
    "PostSyncSql",
]

OVERRIDES = {
    "SyncMode": {
        "allowed": "`Incremental` or `FullRefresh`.",
        "default": "Runtime default is `Incremental` when blank.",
        "effect": "Chooses incremental seek paging or full destination replacement.",
        "risk": "high",
    },
    "KeyColumnsCsv": {
        "allowed": "Comma-separated key columns. Incremental mode currently requires exactly one key.",
        "default": "Blank is not valid for incremental mode.",
        "effect": "Defines seek paging and upsert join keys.",
        "risk": "high",
    },
    "WatermarkColumn": {
        "allowed": "Column name, paired with `WatermarkType`.",
        "default": "`NULL` disables watermark paging.",
        "effect": "Enables watermark + key paging for incremental syncs.",
        "risk": "high",
    },
    "WatermarkType": {
        "allowed": "Type string used by watermark conversion helpers.",
        "default": "`NULL` disables watermark paging.",
        "effect": "Controls how watermark values are converted to and from stored state.",
        "risk": "high",
    },
    "SourceWhereClause": {
        "allowed": "SQL predicate fragment valid in `WHERE (...)` against the source object.",
        "default": "Blank means no extra filter.",
        "effect": "Restricts source reads, counts, and snapshots.",
        "risk": "high",
    },
    "PreSyncSql": {
        "allowed": "Destination-side T-SQL batch.",
        "default": "Blank means skipped.",
        "effect": "Runs before data movement begins.",
        "risk": "high",
    },
    "PostSyncSql": {
        "allowed": "Destination-side T-SQL batch.",
        "default": "Blank means skipped.",
        "effect": "Runs after data movement completes.",
        "risk": "high",
    },
    "BatchSize": {
        "allowed": "Positive integer. Tune it as a throughput-versus-memory control, not just a row-count setting.",
        "default": "No database default confirmed; store explicitly.",
        "effect": "Changes both source `SELECT TOP (...)` read size and `SqlBulkCopy.BatchSize`.",
        "risk": "high",
        "deps": "Review `SyncMode`, `SourceWhereClause`, source row width, large-value columns, and destination log throughput together before changing this field.",
        "examples": "`1000`, `5000`, `20000`",
        "scenario": "Profile the source table first, choose a conservative value for wide rows or LOB data, then validate one controlled run before increasing further.",
        "troubleshooting": "If runs stall on one batch, spike memory, or hold long bulk-copy windows, lower this value and re-check the next run log.",
    },
}


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def infer_type(name: str) -> str:
    if name.endswith("Password"):
        return "nvarchar secret"
    if name.endswith("Mode") or name.endswith("Schema") or name.endswith("Table") or name.endswith("Server") or name.endswith("Database") or name.endswith("Username") or name.endswith("Column") or name.endswith("Type") or name.endswith("Name"):
        return "nvarchar"
    if name.endswith("Csv"):
        return "nvarchar CSV"
    if name.endswith("Seconds") or name.endswith("Count") or name.endswith("Size") or name == "SyncId":
        return "int"
    if name.startswith("Is") or name.endswith("Allow") or name.startswith("Auto") or name.startswith("Create") or name.startswith("Validate") or name == "InsertOnly":
        return "bit"
    return "nvarchar"


def infer_allowed(name: str) -> str:
    if name.endswith("Password"):
        return "Valid secret value."
    if name.endswith("AuthMode"):
        return "`Integrated` for Windows auth; any other non-blank value resolves to SQL auth."
    if name.endswith("Csv"):
        return "Comma-separated values."
    if infer_type(name) == "bit":
        return "`0` or `1`."
    if infer_type(name) == "int":
        return "Positive integer unless the operating model explicitly allows `0`."
    return "Project-specific string value."


def infer_default(name: str) -> str:
    if name in {"ColumnsCsv", "ExcludeColumnsCsv", "SourceWhereClause", "PreSyncSql", "PostSyncSql"}:
        return "Blank means not active."
    if name == "MaxBatchesPerRun":
        return "`NULL` means unlimited incremental batches."
    if name in {"WatermarkColumn", "WatermarkType"}:
        return "`NULL` means watermark paging is disabled."
    if name in {"InsertOnly"}:
        return "Runtime helper default is false."
    return "No database default confirmed; store explicitly."


def infer_effect(name: str) -> str:
    if name.startswith("Source"):
        return "Changes how the runtime connects to or reads from the source side."
    if name.startswith("Destination"):
        return "Changes how the runtime connects to or writes to the destination side."
    if name.endswith("Csv"):
        return "Changes the final sync column or key selection."
    if name.endswith("Sql"):
        return "Runs arbitrary SQL on the destination connection."
    if name == "BatchSize":
        return "Changes batch and bulk-copy size."
    if name == "CommandTimeoutSeconds":
        return "Changes SQL and bulk-copy timeout behaviour."
    if name == "FullScanAllow":
        return "Controls whether incremental mode can start without existing checkpoint state."
    if name == "InsertOnly":
        return "Skips updates and inserts only missing keys during incremental sync."
    if name == "MaxBatchesPerRun":
        return "Stops incremental processing after the configured number of batches."
    if name == "AutoCreateDestinationTable":
        return "Allows the runtime to create a missing destination table from source metadata."
    if name == "CreatePrimaryKeyOnAutoCreate":
        return "Adds a PK on auto-created tables using configured key columns."
    if name == "ValidateDestinationSchema":
        return "Enables required-column validation before sync work."
    if name == "IsEnabled":
        return "Short-circuits the sync before work starts when disabled."
    return "Changes runtime behaviour for this sync definition."


def infer_risk(name: str) -> str:
    if name in {"SyncName", "SyncMode", "KeyColumnsCsv", "WatermarkColumn", "WatermarkType", "SourceWhereClause", "PreSyncSql", "PostSyncSql"}:
        return "high"
    if name.startswith("Source") or name.startswith("Destination") or name in {"BatchSize", "InsertOnly", "FullScanAllow", "AutoCreateDestinationTable"}:
        return "high"
    if infer_type(name) == "bit" or infer_type(name) == "int":
        return "medium"
    return "medium"


def find_refs(lines: list[str], name: str) -> list[str]:
    refs = []
    direct = re.compile(rf"\bcfg\.{re.escape(name)}\b")
    indirect = re.compile(rf'ColumnName "{re.escape(name)}"')
    for idx, line in enumerate(lines, start=1):
        if direct.search(line) or indirect.search(line):
            refs.append(f"`Sync-ConfiguredSqlTable.ps1:{idx}`")
    return refs


def row(name: str, lines: list[str]) -> dict[str, str]:
    override = OVERRIDES.get(name, {})
    refs = find_refs(lines, name)
    return {
        "name": name,
        "type": infer_type(name),
        "allowed": override.get("allowed", infer_allowed(name)),
        "default": override.get("default", infer_default(name)),
        "null": "Store explicit non-NULL values unless the docs call the field optional. The script mixes helper-based defaults with direct casts, so `NULL` is unsafe for several fields.",
        "effect": override.get("effect", infer_effect(name)),
        "side_effects": "Read once at process start. Mid-run edits do not reconfigure the already-running process.",
        "deps": override.get("deps", "Review interactions with `SyncMode`, column selection, and `Sync.TableState` checkpoints before changing this field."),
        "scope": "Usually per sync row in `Sync.TableConfig`; connection fields are also environment-specific.",
        "live": "Safe for future runs only unless stated otherwise. Do not edit `Sync.TableState` during an active run.",
        "refresh": "No cache refresh exists in the script. Start a new process to pick up the change.",
        "examples": override.get("examples", "`example-value`"),
        "scenario": override.get("scenario", "Validate the next run using `Sync.RunLog` and `Sync.RunActionLog` after changing this field."),
        "troubleshooting": override.get("troubleshooting", "Trace the active config row, then compare runtime log output with the stored value."),
        "risk": override.get("risk", infer_risk(name)),
        "confidence": "confirmed",
        "refs": ", ".join(refs) if refs else "No direct references detected.",
    }


def write_reference(rows: list[dict[str, str]]) -> None:
    table = [
        "# Configuration Reference",
        "",
        "This page is generated from `Sync-ConfiguredSqlTable.ps1` usage patterns by `docs/scripts/generate_config_docs.py`.",
        "",
        "| Name | Type | Default | Risk | Confidence | Code refs |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for item in rows:
        table.append(
            f"| `{item['name']}` | {item['type']} | {item['default']} | {item['risk']} | {item['confidence']} | {item['refs']} |"
        )
    table.extend(
        [
            "",
            "## Notes",
            "",
            "- `Get-ConfigRow` loads `c.*` from `Sync.TableConfig`, so the table may contain extra columns that are currently unused.",
            "- `Sync.TableConfig` is read once at process start.",
            "- `Sync.TableState` is updated during the run and acts as the checkpoint source for the next run.",
            "- The highest-risk settings are `SyncMode`, key/watermark settings, connection targets, `SourceWhereClause`, and pre/post SQL hooks.",
            "",
        ]
    )
    (DOCS_ROOT / "configuration" / "reference.md").write_text("\n".join(table), encoding="utf-8")


def write_flag_pages(rows: list[dict[str, str]]) -> None:
    FLAGS_ROOT.mkdir(parents=True, exist_ok=True)
    index_lines = ["# Flag Pages", "", "Generated detail pages for confirmed runtime fields.", ""]
    for item in rows:
        slug = slugify(item["name"])
        index_lines.append(f"- [{item['name']}]({slug}.md)")
        content = f"""# {item['name']}

- Table: `Sync.TableConfig`
- Column: `{item['name']}`
- Data type: {item['type']}
- Allowed values: {item['allowed']}
- Default or observed default: {item['default']}
- Null behaviour: {item['null']}
- Where it is read in code: {item['refs']}
- Functional effect: {item['effect']}
- Side effects: {item['side_effects']}
- Dependencies and conflicts: {item['deps']}
- Scope: {item['scope']}
- Safe to change live: {item['live']}
- Refresh or restart requirement: {item['refresh']}
- Example values: {item['examples']}
- Example scenario: {item['scenario']}
- Troubleshooting: {item['troubleshooting']}
- Risk rating: {item['risk']}
- Confidence: {item['confidence']}
"""
        (FLAGS_ROOT / f"{slug}.md").write_text(content, encoding="utf-8")
    (FLAGS_ROOT / "index.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")


def main() -> None:
    lines = SCRIPT_PATH.read_text(encoding="utf-8").splitlines()
    rows = [row(name, lines) for name in CONFIRMED_ITEMS]
    write_reference(rows)
    write_flag_pages(rows)


if __name__ == "__main__":
    main()
