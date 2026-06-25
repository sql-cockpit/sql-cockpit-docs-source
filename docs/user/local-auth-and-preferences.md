# Local Auth And Preferences

SQL Cockpit now requires a local sign-in before operators can use the dashboard.

This sign-in is workstation-local. It is not tied to SQL Server logins, Active Directory, or a shared identity provider.

## What happens on first run

1. Start the workspace as normal.
2. Open the dashboard URL.
3. If no local SQL Cockpit user exists yet, the app redirects to `/setup`.
4. Create the first local administrator account.
5. The app signs you in automatically and returns to the requested page.

## What is stored locally

SQL Cockpit creates a packaged local SQLite database on the same machine as the app:

- storage location:
  `data/sql-cockpit/sql-cockpit-local.sqlite`
- what it stores:
  local users, password hashes, session records, theme choice, notification state, account/team workspace records, saved connection profiles, and saved instance profiles
- what it does not replace:
  `Sync.TableConfig`, `Sync.TableState`, `Sync.RunLog`, and `Sync.RunActionLog` still live in the SQL Server config database

## Sign in and sign out

- use the username and password created during setup
- use `Preferences` or the header `Sign Out` action to end the current session
- sessions are stored in the local app database and issued to the browser as `HttpOnly` cookies named `sql_cockpit_session`
- session cookies use `SameSite=Lax`, `Max-Age`, and `Expires` so mobile browsers keep the LAN dashboard session across app handoffs and top-level link opens
- sessions last 7 days by default; when an active session has not been seen for at least 15 minutes, the server extends the local `sessions.expires_at` value and reissues the browser cookie with the renewed expiry
- mutating API requests still require a same-origin `Origin` or `Referer`, so the mobile-friendly cookie does not relax write protection

## Change your password

1. Open `Preferences`.
2. Enter the current password.
3. Enter and confirm the new password.
4. Select `Update Password`.

Password guidance:

- use at least 12 characters
- include upper-case, lower-case, and numeric characters
- prefer a unique password for each workstation

## What preferences now follow your local account

- theme mode
- default landing page
- profile picture
- notification read and archive state
- Slack and PagerDuty integration settings
- Source Control Git repository settings
- saved database connection profiles
- saved SQL Server instance profiles
- account-owned workspaces created from the Account page
- dashboard page-intro visibility

That means these values no longer depend on one browser profile alone. They now follow the signed-in SQL Cockpit user on that machine.

## Account workspaces

Signed-in users can create additional private workspaces from the top-right profile dropdown or the Account page.
Each account workspace has its own saved connection and instance profile lists.
The default `My Workspace` remains available for existing personal profiles.
Users can create more than one account workspace, including multiple workspaces with the same display name when the slug field is left blank. SQL Cockpit derives a distinct slug for each workspace, such as `support`, `support-2`, and `support-3`.
Changing workspace also changes the command palette search environment. Object-search syncs, manifests, locks, recent objects, search results, and object definition lookups are scoped by the active workspace, so databases must be synchronized separately in each workspace where you want them searchable.
SQL Cockpit switches the active workspace directly. After `POST /api/workspace/switch` succeeds, the dashboard refreshes the page so workspace-scoped profiles, object-search data, task widgets, and cached dashboard state reload from a clean state instead of carrying state across workspace boundaries.

The command palette default lane is stored in the local account profile as `commandPaletteDefaultMode`. Use **Preferences** to choose `Server Objects` (`index`) or `Quick Links` (`quick`) as the opening mode when the palette starts without a search query.

The dashboard landing page is stored in the local account profile as `defaultPage`. The default value is `/`, labelled **Welcome Page** in the UI. Open **Account**, then change **Default page** to choose where SQL Cockpit sends you when you open the main dashboard URL `/`. Valid values are the options shown in the Account page selector, including `/`, `/connection-manager`, `/instance-manager`, `/ssis-inspector`, `/ssrs-inspector`, `/sql-editor`, `/index-inspector`, and other common operational pages. Invalid or missing values fall back to `/`; legacy saved `/new-tab` values are normalized to `/`.

The profile picture is stored in the local account profile as `profilePicture`.

- storage location: local SQLite `user_preferences.preference_key = profilePicture`
- valid values: empty string; legacy `data:image/...;base64,...` URL; or a versioned compressed avatar object with `sm` 48px, `md` 96px, and `lg` 192px data-URL variants; the Account page accepts PNG, JPG, WebP, or GIF uploads up to 3 MB, center-crops them to square avatars in the browser, and saves only compressed web-sized variants
- default: empty string, so SQL Cockpit shows the signed-in user's initials
- code path: `sql-cockpit-api/components/dashboard-client.js`, `sql-cockpit-api/components/dashboard-shell.js`, `sql-cockpit-api/components/dashboard/profile-picture-utils.js`, `sql-cockpit-api/components/dashboard/dashboard-welcome-page.js`, `sql-cockpit-api/components/dashboard/pages/account-page.js`, `GET /api/preferences`, `PUT /api/preferences`, and `GET /api/workspaces`
- operational risk: low to medium; the compressed image variants are stored in the local application database for the signed-in user, returned to that user with other preferences, and returned to active teammates through `GET /api/workspaces` so team workspace widgets can show member avatars
- safe test: open **Account**, choose **Change Photo** with an image smaller than 3 MB, confirm the avatar appears on the Account page, top-right profile menu, and team workspace member strip, then use **Remove** to return to initials

The Source Control Git settings are stored in the local account profile as `sourceControlSettings`.

- storage location: local SQLite `user_preferences.preference_key = sourceControlSettings`
- valid values: `repoPath`, a local Git working-tree path; `defaultObjectTypes`, an array containing `View`, `Procedure`, `Function`, `Trigger`, and/or `Agent Job`
- default: empty `repoPath` and all supported object types
- code path: `sql-cockpit-api/server.js`, `sql-cockpit-api/lib/source-control-store.js`, `sql-cockpit-api/components/dashboard/pages/source-control-page.js`, `GET /api/source-control/settings`, `PUT /api/source-control/settings`, and `POST /api/source-control/settings`
- operational risk: medium to high; snapshot, commit, and push actions run in the configured repository, broad filters can write many SQL definition files, and push can publish sensitive SQL through the repository remote
- safe test: create a disposable local Git repository, save the path from **Source Control**, select one object type and a narrow database/schema filter, run a snapshot, review status and diff, then push only to a disposable remote before granting production users `sourceControl.push`

## Header account menu

The top-right profile control opens account actions for the signed-in local user.

- desktop behavior: at `lg` width and above, a compact dropdown opens from the profile button
- mobile/tablet behavior: below `lg`, the same profile button opens a full-screen drawer from the right using fixed `inset-0` positioning and dynamic viewport height, matching the mobile navigation drawer pattern; drawer actions use larger touch rows and spacing than the desktop dropdown, content scrolls when workspace controls overflow, and the drawer can be dismissed with the close button or `Esc`
- code paths affected: `sql-cockpit-api/components/dashboard-shell.js` and `sql-cockpit-api/app/globals.css`
- operational risk: low; this changes only dashboard navigation chrome and does not change authentication, RBAC, session storage, preferences, workspace membership, or SQL execution behavior
- safe test: confirm desktop still opens the compact dropdown, then resize below the `lg` shell breakpoint, open the profile control, confirm the drawer slides in from the right and covers the whole viewport, confirm **Account**, **Workspaces**, **Preferences**, and **Sign Out** remain reachable, and close it with the close button and `Esc`

The welcome-page widget layout is stored in the local account profile as `welcomePageLayout`.

- storage location: local SQLite `user_preferences.preference_key = welcomePageLayout`
- valid value: versioned JSON with `version` and `widgets`
- widget fields: `id`, `type`, `size`, `responsiveColSpans`, `rowSpan`, `collapsed`, and optional `settings`; legacy `colSpan` and `mobileColSpan` fields are still accepted and normalized; layouts are capped at 30 widgets and older/manual layouts with more entries are normalized down to the first 30
- supported widget types: `clockGreeting`, `quickActionSearch`, `activeWorkspace`, `startingPoints`, `openTabs`, `recentObjectCache`, `runningTasks`, `nextTasks`, `objectCacheInsights`, `taskHealth`, `changeMix`, `cacheLargestDatabases`, `cacheFreshness`, `cacheSyncActivity`, `objectTypeCounts`, `graphObjectTypeDonut`, `graphObjectTypeBars`, `graphSourceShare`, `graphSourceBars`, `graphDatabaseTreemap`, `graphFreshnessStack`, `graphFreshnessRings`, `graphSyncActivityBars`, `graphUploadDeleteBalance`, `graphRecentChangeBars`, `graphCoverageMatrix`, `graphSourceFreshness`, and `coreNavigation`
- supported legacy sizes: `full`, `wide`, `half`, and `third`, normalized to CSS-grid column spans
- supported `responsiveColSpans.desktop`, `responsiveColSpans.tablet`, and `responsiveColSpans.mobile` values: `2` through `12`, each across a 12-column grid for that breakpoint; use `12` for full width; mobile defaults to `12` for every widget so saved dashboards stack cleanly on phones, while users can still opt into denser mobile widgets from the responsive editor
- supported row spans: `1`, `2`, and `3`, used as compact widget height hints
- clock/greeting settings: `timeFormat` (`12h` or `24h`), `showSeconds` (`true` or `false`), `dateStyle` (`short`, `medium`, or `full`), `textScale` (`compact`, `default`, or `large`), and `theme` (`classic`, `neonDigital`, `terminal`, or `glass`)
- recently changed object-cache settings: `objectType` (`All`, `Table`, `View`, `Procedure`, `Function`, `Trigger`, `Column`, `Index`, `Constraint`, `Synonym`, or `Agent Job`), `sourceServer` (`All` or an instance name returned by the active workspace cache), `databaseName` (`All` or a database name returned for the selected instance), and `limit` (`3` through `50`); the widget reads instance/database filter options from compact `GET /api/object-search/status?compact=1`, then fetches only the displayed recent rows from `GET /api/object-search/recent` using the selected type, instance, database, and display count
- default: the shared dashboard template copied from `joel.murphy`, upgraded with insight and graph widgets: large clock/greeting, active workspace, running tasks, next tasks, Object Cache Health, Task Health, Change Mix, Largest Cached Databases, Cache Freshness, Cache Sync Activity, Object Type Counts, 12 object-cache graph widgets, a full-width recently changed Procedure object-cache widget showing 50 items, starting points, action search, open tabs, and core navigation widgets
- code path: `sql-cockpit-api/components/dashboard-client.js`, `sql-cockpit-api/components/dashboard/dashboard-welcome-page.js`, compact `GET /api/object-search/status?compact=1` state for workspace-scoped cache metadata, Object Cache Health, Largest Cached Databases, Cache Freshness, Cache Sync Activity, and status-backed graph widgets, `GET /api/object-search/recent` for displayed recent rows, `GET /api/object-search/recent?limit=50&perTypeLimit=5` for Change Mix and recent-change graph widgets, `GET /api/object-search/analytics/object-types` for Object Type Counts and type graph widgets, active-workspace-scoped `GET /api/task-runs?status=running` for the `runningTasks` and Task Health widgets, active-workspace-scoped `GET /api/tasks?nextRun=scheduled` for the `nextTasks` widget, active-workspace-scoped `GET /api/tasks?limit=500` for Task Health, and existing `GET /api/preferences` and `PUT /api/preferences`
- operational risk: low; this is personalization plus a workspace-scoped read from object search and does not alter SQL execution, RBAC, saved profiles, or workspace membership; the 30-widget cap prevents excessive dashboard startup work as more widgets are added, inactive Welcome Page tabs park the widget grid plus widget fetch/timer work until the user returns, and compact status plus recent/task analytics requests are deduped briefly in the browser to avoid duplicate startup traffic
- safe reset: open **Welcome Page**, select the widget configuration icon, then use the reset icon and confirm the messagebox; after changes, use the browser Network tab to confirm `/` uses `GET /api/object-search/status?compact=1`, loads the Welcome widget grid as a tab/page chunk inside the single dashboard, and loads non-Welcome feature chunks only when those workspace tabs open

Dashboard workspace tabs are stored in browser local storage under `sql-cockpit.workspace-tabs.v1`.

- valid value: route-backed tab objects containing `key`, `href`, `label`, and `openedAt`
- default: one `/` Welcome Page tab
- blank new-tab behavior: the tab-strip **New tab** button creates a unique `/?workspaceTabKey=<id>` route so multiple blank action tabs can exist at the same time; these blank tabs show an action list and do not load the configurable Welcome Page widget grid
- tab control behavior: desktop tabs use compact labels and icon controls to fit more open routes in the strip; on mobile, the active-tab control opens a slide-down selector that spans the available screen width and scrolls vertically so all open tabs remain reachable
- mobile pull-to-refresh: the indicator appears below the sticky dashboard header with horizontal and vertical padding so the refresh pill does not collide with the header or tab chrome
- code path: `sql-cockpit-api/components/dashboard-client.js`, `sql-cockpit-api/components/dashboard/dashboard-route-metadata.js`, and `sql-cockpit-api/components/dashboard/dashboard-welcome-page.js`
- operational risk: low; this changes browser-local tab state and dashboard navigation only, and does not change RBAC, SQL execution, saved profiles, workspace membership, or server-side user preferences
- safe test: open the dashboard, select the tab-strip **New tab** button twice, confirm two separate **New Tab** tabs exist and each shows the action list, narrow the viewport, open the active-tab selector, confirm it spans the available screen width with a scrollable tab list, then switch back to **Welcome Page** and confirm its widget layout is unchanged

The dashboard page-intro panel state is stored in the local account profile as `dashboardIntroPanels`.

- storage location: local SQLite `user_preferences.preference_key = dashboardIntroPanels`
- valid value: JSON object keyed by dashboard section; each value stores `expanded: true` or `expanded: false`
- default: `{}`; page intro panels are collapsed by default when no saved state exists
- code path: `sql-cockpit-api/components/dashboard-client.js`, via existing `GET /api/preferences` and `PUT /api/preferences`
- operational risk: low; this changes only page-intro visibility and does not alter SQL execution, RBAC, saved profiles, or workspace membership
- safe reset: open **Preferences** and use **Reset intro panels**

The account integration settings are stored in the local account profile as `integrationSettings`.

- storage location: local SQLite `user_preferences.preference_key = integrationSettings`
- setup routes: `/account/integrations`, `/account/integrations/slack`, and `/account/integrations/pagerduty`
- API routes: `GET /api/integrations`, `PUT /api/integrations/slack`, `POST /api/integrations/slack/test`, `PUT /api/integrations/pagerduty`, and `POST /api/integrations/pagerduty/test`
- valid Slack values: `enabled`, Slack incoming-webhook URL from `https://hooks.slack.com/services/...`, and optional channel override
- valid PagerDuty values: `enabled`, Events v2 routing key, HTTPS Events API URL, and optional service label
- defaults: both integrations disabled; Slack fields blank; PagerDuty routing key blank; PagerDuty URL `https://events.pagerduty.com/v2/enqueue`
- secret handling: read APIs return configured flags instead of raw webhook URLs or routing keys; leaving the secret field blank on the setup page preserves the stored secret
- code paths: `sql-cockpit-api/server.js`, `sql-cockpit-api/components/dashboard-client.js`, `sql-cockpit-api/lib/rbac-auth-store.js`, and `sql-cockpit-api/lib/task-management-store.js`
- operational risk: medium for Slack because task names and redacted failure summaries can reach shared channels; high for PagerDuty because the test action and real job failures can create incidents
- safe test: configure on the focused setup page, send the test notification, confirm the destination received it, then use **Notifications** to keep only the required job-event actions enabled
- confidence: confirmed for storage, defaults, redacted reads, setup routes, test routes, and Task Manager delivery

Storage and access:

- workspace records are stored in the local SQLite `workspaces` table with `owner_user_id` set to the signed-in user
- account workspace slugs are unique per signed-in user; explicit slug values must not duplicate another workspace owned by the same user
- profile lists for additional account workspaces are stored in `user_preferences` under `workspace.personal.<workspaceId>`
- team-created workspaces use the same `workspaces` table with `team_id` set, and profile lists remain in `settings.workspace.team.<teamId>`
- access checks are enforced by the API before reading or saving workspace profiles

## Safe handling notes

- treat saved SQL-auth connection passwords as sensitive because they are stored in the local app database for the signed-in user
- prefer integrated SQL authentication in saved profiles whenever possible
- keep the app bound to loopback unless a wider exposure has been reviewed
- do not copy the local auth database between machines unless you intend to move that workstation-local state

## If you forget the local password

There is currently no password-recovery email flow.

The safe reset procedure is:

1. stop the SQL Cockpit workspace
2. back up `data/sql-cockpit/sql-cockpit-local.sqlite`
3. delete that file only if you accept losing the local users, sessions, saved profiles, and user preferences stored in it
4. restart the workspace
5. run setup again to create a new local administrator

This does not change the SQL Server config database. It only resets the workstation-local SQL Cockpit auth store.
