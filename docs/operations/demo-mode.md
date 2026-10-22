
## Safe exploration controls

Demo presentation explicitly enables reviewed Welcome Page navigation cards, account/workspace/preferences navigation, tab scrolling and local new tabs, plus pure task/schedule validation. Opening a page does not grant its write permissions. Labels such as Notifications and pagination are recognized as UI browsing. All backend endpoint, RBAC, store and Agent restrictions remain unchanged: validation cannot schedule or run tasks, and SQL execution, saved configuration changes, service control and ingestion remain blocked. Unknown controls still default to unavailable. No new flags or persistence are introduced.

Safe check: sign into the demo, open widget links and drawer panels, scroll/create local tabs and inspect existing records. Check pure validation where the composer is authorized; confirm Save, Run, Sync and service actions remain unavailable and direct mutation requests still return the demo 403. UI changes remain in memory only.
