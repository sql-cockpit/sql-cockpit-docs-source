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
- sessions are stored in the local app database and issued to the browser as `HttpOnly` cookies

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
- notification read and archive state
- Slack and PagerDuty integration settings
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

The command palette default lane is stored in the local account profile as `commandPaletteDefaultMode`. Use **Preferences** to choose `Server Objects` (`index`) or `Quick Links` (`quick`) as the opening mode when the palette starts without a search query.

The dashboard landing page is stored in the local account profile as `defaultPage`. The default value is `/new-tab`, labelled **Welcome Page** in the UI. Open **Account**, then change **Default page** to choose where SQL Cockpit sends you when you open the main dashboard URL `/`. Valid values are the options shown in the Account page selector, including `/new-tab`, `/connection-manager`, `/instance-manager`, `/sql-editor`, `/index-inspector`, and other common operational pages. Invalid or missing values fall back to `/new-tab`.

The welcome-page widget layout is stored in the local account profile as `welcomePageLayout`.

- storage location: local SQLite `user_preferences.preference_key = welcomePageLayout`
- valid value: versioned JSON with `version` and `widgets`
- widget fields: `id`, `type`, `size`, `colSpan`, `rowSpan`, `collapsed`, and optional `settings`
- supported widget types: `clockGreeting`, `quickActionSearch`, `activeWorkspace`, `startingPoints`, `openTabs`, `recentObjectCache`, and `coreNavigation`
- supported legacy sizes: `full`, `wide`, `half`, and `third`, normalized to CSS-grid column spans
- supported column spans: `3`, `4`, `6`, `8`, and `12` across the 12-column desktop grid
- supported row spans: `1`, `2`, and `3`, used as compact widget height hints
- clock/greeting settings: `timeFormat` (`12h` or `24h`), `showSeconds` (`true` or `false`), `dateStyle` (`short`, `medium`, or `full`), and `textScale` (`compact`, `default`, or `large`)
- recently changed object-cache settings: `objectType` (`All`, `Table`, `View`, `Procedure`, `Function`, `Trigger`, `Column`, `Index`, `Constraint`, `Synonym`, or `Agent Job`), `sourceServer` (`All` or an instance name returned by the active workspace cache), `databaseName` (`All` or a database name returned for the selected instance), and `limit` (`3` through `50`); the widget reads instance/database filter options from `GET /api/object-search/status`, then fetches only the displayed recent rows from `GET /api/object-search/recent` using the selected type, instance, database, and display count
- default: the shared dashboard template copied from `joel.murphy`: large clock/greeting, active workspace, a full-width recently changed Procedure object-cache widget showing 50 items, starting points, action search, open tabs, and core navigation widgets
- code path: `sql-cockpit-api/components/dashboard-client.js`, `GET /api/object-search/status` for workspace-scoped `recentObjectCache` filter options, `GET /api/object-search/recent` for displayed widget rows, and existing `GET /api/preferences` and `PUT /api/preferences`
- operational risk: low; this is personalization plus a workspace-scoped read from object search and does not alter SQL execution, RBAC, saved profiles, or workspace membership
- safe reset: open **Welcome Page**, select the widget configuration icon, then use the reset icon and confirm the messagebox

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
