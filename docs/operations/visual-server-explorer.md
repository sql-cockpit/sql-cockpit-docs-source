# Visual Server Explorer

Visual Server Explorer is the graph-first companion to Server Explorer. It opens from `Engineering > Visual Server Explorer` and uses saved Instance Manager profiles.

The graph is read-only. It starts with the selected server and loads all returned online user databases for that instance as database nodes only. Expanding a database makes a focused metadata call for that one database, then adds schema nodes, object groups, objects, and returned child metadata for columns, indexes, constraints, and triggers. The production Object Explorer keeps the graph data model separate from the renderer, so the current Graphviz adapter can be replaced later without changing provider or state contracts. The metadata source can be the live SQL Server catalog or the active workspace's object-search cache. SQL Agent jobs and job steps are loaded on demand from the existing SQL Agent inventory endpoint.

```mermaid
flowchart LR
    Profile[Saved instance profile] --> Explorer[Visual Server Explorer]
    Explorer --> Metadata[/api/servers/explorer]
    Metadata --> DB[Database nodes]
    DB --> Expand[Expand database]
    Expand --> Focused[Focused database metadata call]
    Focused --> Schema[Schema nodes]
    Schema --> Objects[Tables, views, procedures, functions, triggers, synonyms]
    Objects --> Children[Columns, indexes, constraints, triggers]
    Explorer --> CacheStatus[/api/object-search/status]
    CacheStatus --> CachedDB[Cached database nodes]
    CachedDB --> CacheSearch[/api/object-search/search]
    CacheSearch --> Schema
    Explorer --> Agent[/api/sql-agent/jobs]
    Agent --> Jobs[Agent jobs]
    Jobs --> Steps[Job steps]
    Explorer --> State[Graph state]
    State --> UX[Search, filters, fullscreen, pan/zoom, overlays]
    State --> Renderer[Graphviz DOT adapter]
```

## Safe Use

1. Select one saved instance profile.
2. Let the instance inventory load all returned online user databases as database nodes.
3. Drag the graph background or adjust zoom to frame the area you are inspecting.
4. Use `Fit`, `Reset`, `Centre`, fullscreen, or keyboard shortcuts to frame the current graph.
5. Use the minimap to see the full graph footprint and drag the viewport rectangle to move around large layouts.
6. Use the legend in the graph corner to map node colors to SQL object types.
7. Use the diagram overlay buttons for zoom, zoom level, `Reset`, `Fit`, `Centre`, keyboard shortcut popup, and fullscreen enter/exit.
8. Use `Expand all` and `Collapse all` to open or close visible loaded branches. `Expand all` does not bulk-load unloaded database metadata; expand database nodes deliberately before expanding their loaded child branches.
9. Search by object name or type and use next/previous result controls to move between matches.
10. Select a database and use the inline `+` button, **Expand node** in the side panel, the context menu, or double-click the generated SVG node to load object details for that database. Opened nodes are selected and snapped to the center of the graph view; expand actions show an in-node spinner and are locked until the updated diagram has rendered.
11. Expand one schema, object group, and object node the same way.
12. Use the inline `i` button to review the object information popup before loading more branches; it includes metadata, copy actions, pin/hide actions, and definition previews where returned.
13. Use `Load Agent Jobs` only when you need job and step metadata.
14. Switch **Metadata source** to `Object-search cache` when you want faster cache-backed browsing and have already synced the instance into object search.

## Operational Notes

- Authentication and certificate handling come from the selected Instance Manager profile.
- `/api/servers/explorer` remains read-only. The instance call draws database nodes; focused database calls read schema, object, and child metadata.
- Cache mode uses `GET /api/object-search/status` for cached database nodes and `GET /api/object-search/search?q=&server=<server>&database=<database>&limit=5000` for expanded database branches.
- The cache setting is stored per user in `user_preferences` as `visualServerExplorerSettings.metadataSource`, with valid values `live` and `cache`; default is `live`.
- Cached metadata can be stale or incomplete until the active workspace object-search index is synced for the selected instance.
- The graph model lives under `sql-cockpit-api/components/object-explorer` and tracks nodes, edges, expanded/collapsed branches, loading nodes, selected/hovered node, pinned/hidden nodes, search query, filters, viewport state, fullscreen, warnings, and error state.
- DOT rendering uses `@hpcc-js/wasm/graphviz`; `graphvizLayoutProvider.js` converts the current graph model into DOT and `ObjectExplorerCanvas.js` binds selection, inline expand buttons, keyboard, hover, context-menu, and double-click behavior to the generated SVG.
- Graphviz is retained because it gives high-quality automatic layout without a new heavy dependency. Its trade-off is that branch expansion recomputes layout for the visible graph; pan, zoom, hover, search highlighting, and selection do not require a DOT rerender.
- Node colors are defined per object type in `graphvizLayoutProvider.js`; the canvas legend and minimap reuse the same style map.
- Node and font sizing adapt to the visible graph size, making small graphs easier to read while keeping dense graphs compact enough to navigate.
- The viewport zoom ceiling rises with graph density so expanded subgraphs can be inspected at higher magnification.
- Minimap node positions are measured only after Graphviz renders a changed graph shape. Minimap viewport dragging is throttled with `requestAnimationFrame`, and canvas drag panning updates the SVG transform directly before committing React state at the end of the drag.
- Node click, hover, context menu, and keyboard handling are delegated from the graph container instead of attaching closures to every generated SVG node.
- Hover highlighting is canvas-local, toolbar/filters/overlay rendering is memoized, and search input is debounced with precomputed node search text.
- The minimap intentionally caps rendered detail so large layouts stay navigable without drawing every edge.
- `/api/sql-agent/jobs` reads `msdb` job and step metadata.
- No database configuration tables are introduced.
- No new database flags or runtime sync settings are introduced.
