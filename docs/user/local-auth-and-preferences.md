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


### Compact desktop console toolbar

At desktop widths (1024px and above), the shared console toolbar uses 36px search and utility controls and a 52px minimum header height to leave more room for operational content. Narrower screens retain 44px touch controls and a 68px minimum header height. The header can wrap when space is limited. This is a presentation change in `components/dashboard-shell.js`; it introduces no stored preference or database flag.

To verify safely, open the console at desktop and mobile widths, check search suggestions, account controls, and focus mode, and confirm keyboard focus remains visible. No database operation is required.

The workspace tab strip’s **New tab** (+) button has a bordered surface matching the tab controls in light and dark themes. In the Welcome Page’s Active Workspace widget, the workspace selector and **Switch** button share one row, including on narrow screens. The selector shrinks to fit while the action stays visible. Existing workspace-switch permissions and disabled states still apply. Verify at 375px and desktop widths; these layout changes add no settings or persistence.

The navigation drawer uses a short perspective-fold transition with edge shadow when entering or leaving focus mode, and when opening or closing mobile navigation. Desktop content shifts with the drawer. Hidden navigation becomes invisible and unavailable to keyboard focus after closing. These navigation transitions run even when the operating system requests reduced motion; other reduced-motion rules still apply. No additional preference is stored. Check the focus toggle in both directions and mobile navigation; enable reduced motion to confirm that drawer, focus rail, backdrop, and desktop content transitions still animate.

Opening or closing the navigation drawer via the focus-mode toggle does not show a toast notification. The drawer itself provides visual feedback, and the existing focus-mode preference is still saved. Verify by toggling repeatedly and checking that no focus-mode notifications accumulate.

A successful workspace switch shows one **Workspace changed** toast naming the active workspace, including after the normal page reload. A transient marker in browser tab session storage (`sql-cockpit:workspace-switch-toast`) contains the target workspace key and creation timestamp; it is consumed once when that workspace is active and expires after 60 seconds. This is not a user setting or database flag. Storage failures do not block switching, but may omit the toast. Safe verification: switch to an accessible workspace, confirm one toast after reload, then refresh again and confirm it does not repeat. Calls that explicitly disable notifications remain silent.

Console button icons use a shared fully rounded border and solid background in the header, navigation, and page content. Light and dark themes use corresponding solid surfaces; primary buttons use a matching blue icon surface, while edit, success, and danger icons use their parent button’s semantic background and border colours. Icons retain their existing labels and action colours. This adds no preference. Verify icon-only controls, icon-and-text actions, disabled buttons, and narrow layouts in both themes.

Navigation items and workspace tab titles share route-based feature icons instead of dots. The active route icon uses a highlighted border, background, and glyph; live navigation items retain a small green status marker. Child routes inherit their feature’s icon, and focus navigation uses the same icons. No preferences or permissions change. Check parent/child navigation, desktop tabs, and the mobile active-tab selector.

Focus-mode navigation rail controls use a single fully rounded outer border with an unframed icon inside, including navigation links and the drawer toggle. Active highlighting and tooltips remain available.

Focus-rail section headings use compact 8px type with reduced letter spacing to fit the narrow rail; All rail sections use readable names: Overview, Operations, Data Sync, Development, Account, Access, and System. Expanded-menu heading sizes are unchanged.

The compact agent-status control is centred on the same axis as the focus-rail navigation and uses the same 36px diameter. Its connection-state colour and status marker remain visible.

Desktop workspace tabs size to their full titles rather than shrinking or truncating labels. When tabs exceed the available row width, use horizontal scrolling or the tab navigation controls. The mobile tab selector keeps its compact layout.

Workspace-tab arrows scroll smoothly in either direction over 320ms, moving by roughly 70% of the visible strip. Selecting a hidden tab smoothly brings it into view without scrolling the page. Already visible tabs stay in place. Wheel input interrupts the animation. Like the drawer animation, this runs regardless of reduced-motion preference. Verify both arrows and selection of an off-screen tab with an overflowing tab row.

Navigation help controls use one circular button surface with a plain question-mark glyph, avoiding nested circles in both expanded and focus navigation. Hover, keyboard focus, and help text behavior are preserved.

The header logo is visible only when the full navigation drawer is hidden: in desktop focus mode or with mobile navigation closed. The expanded drawer supplies the logo when open. No additional preference is stored.

Expanded navigation groups use a minus icon with the same rounded border and solid surface as the collapsed group’s plus icon. The toggle retains its accessible expanded state and label.

Welcome Page widget buttons use fully rounded borders: icon-only actions are circular and text actions are pill-shaped. Icon-only actions use a single outer button frame. This includes widget content and widget editing controls. No settings or stored layout values change.

Across the console, buttons containing only an icon (directly or in a single wrapper) use the button’s outer frame without a second border or background on the icon. Buttons with visible text retain their separate icon styling.

Expanded navigation labels shrink only on overflow, down to a 10px minimum, and recalculate on resize and font loading. Parent labels start at 14px and child labels at 12px. Longer labels retain a full-name tooltip. No preference is stored.

Shared dashboard text fitting (`components/use-dashboard-text-fit.js`) reduces overflowing compact button labels, headings, and truncated labels in half-pixel steps to an 11px minimum (already smaller text is not enlarged). It restores original sizing when space returns and responds to new content, font loading, and resizing. Paragraphs, table data, code, form values, editable content, and icon wrappers are excluded. Existing navigation fitting retains its 10px minimum. Developers can opt a subtree out with `data-text-fit="off"` or opt a label in with `data-text-fit`. No user setting or database flag is introduced. Check long labels at desktop and narrow widths, then widen the window to confirm recovery.

Light-mode neutral buttons and focus-rail links use a stronger slate outline for visibility on white surfaces. Rail hover borders darken, while active navigation retains a blue border. Primary and semantic action button borders keep their intent colours. Dark-mode styling is unchanged.

Header notification, theme, and account controls share a 36px desktop footprint and 44px mobile footprint. The account trigger displays the saved profile image as a standalone circular avatar, with initials when no image is set. It retains accessible button semantics for keyboard operation and menu state, without a surrounding button surface. Existing profile-picture storage is unchanged.

Widget task rows, open-tab rows, starting-point actions, and action-search results use 16px horizontal and 10px vertical padding so text and icons remain inset from their rounded edges. Icon-only controls retain their existing dimensions.

The expanded navigation drawer is 260px wide. Desktop content and explorer-overlay offsets match this width; the compact focus rail remains 84px. Existing label fitting accommodates the narrower menu.

Expanded-menu help buttons use an 18px circle and an 11px question mark; focus-rail help controls retain their compact sizing.

In demo mode, the command-palette overlay starts below the demo banner using `--demo-banner-height` (40px fallback). Its panel height subtracts the banner and existing outer padding in both opening and closing states. Verify by opening search with the demo banner visible and checking that the banner and palette controls remain accessible.


### Glass console surfaces

The console uses a shared glass theme with the existing blue/slate palette: translucent panels, fine highlighted edges, soft depth shadows, frosted navigation/header/tab surfaces, and inset form controls. Shared panels, cards, Welcome Page widgets, account menus, command palette, and footer use the theme. Semantic warning/success/danger colours remain distinct. Widget/panel padding is 20px on desktop and 16px on narrow screens; widget grids use 16px gaps (12px on mobile).

Implementation: `dashboard-glass-theme` in `components/dashboard-shell.js`, surface classes in `components/dashboard-density.js`, and scoped CSS tokens in `app/globals.css`. These are presentation tokens, not database settings; the existing saved `theme` preference still selects light or dark. No new persisted settings, API endpoints, permissions, or agent routing changes are introduced. The system reduced-transparency preference selects opaque surfaces; browsers without blur support retain translucent gradient backgrounds. Blur is restricted to structural surfaces to limit rendering cost.

Safe verification: inspect Welcome Page widgets, a form, a table, navigation/focus mode, and account menu in both themes at desktop and mobile widths. Confirm text and intent colours remain legible and popups are not clipped. The agent-required boundary remains enforced; do not bypass it to inspect live SQL workflows.

Glass-theme actions are compact: 32px normal buttons, 28px compact actions, and 30px icon-only widget buttons, with 12px labels. Text widget rows use 8px vertical/14px horizontal padding; shared form inputs use a 34px minimum. The header is 56px minimum. Coarse-pointer devices retain 40px action targets. Panel spacing stays generous. These are CSS presentation defaults, not stored settings.

The glass workspace tab strip is 46px high with a blue active underline. The Tabs manager is available whenever multiple tabs are open, not only after seven tabs. Its focused search filters open tabs by title or page name, with an explicit empty result state; route icons match the sidebar. Closing and switching retain existing behavior, and keyboard focus reveals tab-close controls. Search is transient React state and resets when reopening the desktop manager; no stored preference is added. Verify filtering, empty results, selection, close, and the mobile selector.

The scrolling tab strip uses equal 30px arrow/new-tab controls, subtle edge fades where additional tabs exist, and compact circular close targets. Scroll arrows disable at the corresponding end. Overflow updates on scrolling, resizing, and tab changes. Full titles, smooth scrolling, reordering, and the mobile selector remain available. Check both scroll limits and opening/closing tabs while the row overflows.

Hovering over a workspace-tab scroll arrow with a mouse scrolls continuously at approximately 360px/second. Scrolling stops on pointer leave/cancel, window blur, reaching the end, wheel input, or unmount. Click and keyboard activation still perform the existing smooth page step; touch does not trigger hover scrolling. No preference is stored. Verify both hover directions and stopping after moving the pointer away.

The command palette now applies light-mode styling throughout results, details, filters, scope selectors, metadata chips, and definition preview. Light mode uses dark slate text, white inputs, pale blue selected controls, and visible boundaries; dark mode retains its existing palette. Verify Server Objects and Quick Links, selected filters, empty results, detail/code previews, and disabled controls in both themes.

Quick Links and object-result cards in the light command palette use white surfaces, slate titles/descriptions, pale route badges, and a blue selected-row indicator. Hover and keyboard selection have separate visible states; result rows retain their existing navigation behavior.

AutoPilot chat uses light message surfaces, blue user bubbles/avatars, readable prompt suggestions, dark slate composer text, and darker warning/success labels in light mode. These styles apply to embedded command-palette chat and standalone chat, while dark mode remains unchanged. This changes presentation only; inference destinations, providers, and conversation data are unaffected.

Notification and theme controls share the same header-button sizing class: 36px desktop and 44px mobile, including when notifications are inside a popup wrapper.

Core Navigation widget links use the same route icons as the sidebar and workspace tabs, alongside their text labels.

The profile avatar opens a viewport-anchored right-side glass drawer with a mirrored 3D fold on opening and closing. Existing workspace selection, account, workspace management, preferences, and sign-out controls are retained. The drawer scrolls independently, traps keyboard focus, closes on Escape/backdrop/close button, and restores focus to the avatar. The animation follows the existing navigation override for reduced motion. Demo-banner spacing is retained. No new preference is stored. The duplicate footer product label is removed; copyright and build details remain.

The footer copyright notice includes the current calendar year and 8px vertical/12px horizontal padding.

Mobile navigation is independent of the saved desktop focus-mode preference: the hamburger remains available and opens the left drawer even if desktop focus mode is enabled. Opening the right account drawer closes the mobile left drawer, and opening mobile navigation closes the account drawer. Escape closes either drawer. Desktop focus-mode toggles retain the left navigation/rail behavior.

Upcoming tasks on the Welcome Page are informational panels with compact rounded corners and consistent internal padding. Use the task scheduler action in the widget header to manage tasks.

The account drawer close control uses a pointer cursor, hover rotation and press feedback. The close-control animation remains enabled regardless of the system motion preference.

The mobile navigation drawer and account drawer share the same circular close-control styling and hover/press feedback.

Statistics cards use neutral glass surfaces in both themes. Muted blue, sage and sand accents distinguish informational, success and warning tones in icons and badges without saturated card fills.

The dashboard top bar uses a charcoal-to-black gradient in both light and dark themes, with light search text and outlined utility controls. The selected theme still controls the rest of the dashboard.

On phone viewports below 640px, both navigation and account drawers fill the available screen width and dynamic viewport height, with safe-area padding. Demo mode keeps the banner visible above the drawers. Larger screens retain the compact drawer widths.

The workspace tab manager fills phone viewports below 640px, retaining search and footer actions with a scrollable tab list and explicit close control. Safe-area insets and the demo banner remain respected.

On phones the command palette fills the viewport with compact search, modes, filters and results. Repeated criteria and keyboard hints are hidden. Object details replace the results with a Back to results control instead of splitting the screen.

The top bar, left navigation drawer/rail and right account drawer share a near-black grey gradient in both appearance themes. Drawer text and workspace controls retain light foregrounds for contrast.

On mobile the palette mode switcher is the top row, with the shared animated circular close control. The demo banner has an OK acknowledgement that hides it for the current mounted session and releases its reserved height; all read-only restrictions and accessible action explanations remain active. No preference is persisted.

The demo banner uses a compact two-column layout: heading and message stacked on the left, with the acknowledgement button on the right. Phone spacing and typography are reduced while preserving the full read-only explanation.

Navigation drawers close when a page is selected or navigation begins. On phones, notifications open as a viewport-level fullscreen panel with a scrolling list, safe-area padding and demo-banner offset; header/footer controls remain available.

## Install SQL Cockpit on a phone

The app advertises `/manifest.webmanifest` with stable ID/start URL `/`, standalone display, near-black launch colour, 192/512px icons and a separate maskable icon. iOS uses a 180px Apple touch icon. Installation requires HTTPS (localhost is accepted for development). An installed app still needs sign-in and connectivity for operational features; installation grants no SQL, notification or account permissions.

On mobile touch screens, a dismissible Add to Home Screen suggestion appears after 30 seconds when a supported browser advertises installation, or on iPhone/iPad where Share-menu instructions are provided. Android/Chromium installation is launched only after tapping the button and uses the one-shot `beforeinstallprompt` event. iOS uses Share → Add to Home Screen → Add; no native install prompt is simulated. Already installed/standalone sessions and login/setup screens suppress promotion. Dismissal is stored only as a timestamp in browser localStorage key `sql-cockpit-install-dismissed-until` (14-day cooldown, absent default). Demo sessions dismiss in memory only. Clearing that one key safely resets the suggestion; it affects no server state or customer data.

Production registers `/sw.js` with scope `/` and no HTTP cache. It caches only the public `/offline.html` reconnect page. Navigations use the network and fall back only on network failure; HTTP error/auth/maintenance responses are preserved. API calls, SQL data, authenticated pages, static bundles and account responses are never cached by this worker. Development does not register it, avoiding stale hot-reload assets. Updates use the browser's normal worker lifecycle; no forced reload interrupts unsaved work. Existing installations can be removed through browser/OS app settings, or the worker through browser developer tools if troubleshooting.

Safe verification: run `node --test tests/pwa.test.js` from the API repo, check the manifest/icons and `/sw.js` over HTTPS, then test Android installation and iOS Share-menu installation on physical devices. Confirm standalone launch, dismissal cooldown, online sign-in, offline reconnect screen, and no cached API/SQL responses. Desktop/in-app browser checks cannot reproduce the native OS install dialog. No feature flag, persistence provider or API endpoint is added.

## Device styling with Ionic

The dashboard loads Ionic Core 9's toolbar custom element in the browser and its required core stylesheet. Ionic detects iOS/Material mode; `IonicDeviceStyle` exposes the resolved mode as `data-ionic-mode` and standalone/browser display as `data-app-display` on the document root. Neither attribute is a persisted preference or server flag. Existing theme classes remain authoritative for the light/dark palette; the toolbar keeps the near-black chrome in both themes.

On screens below 1024px, iOS uses softer panel/control corners and subdued press feedback, while Material uses circular top-bar controls and its platform toolbar sizing. Controls have 44px touch footprints. Safe-area top padding protects the status bar/notch in standalone mode; left/right/bottom insets protect landscape controls and the home indicator. The visible demo banner owns the top inset while present. Phone overlays remain fullscreen with square outer edges; rounded cards sit inside them rather than cropping the usable screen. Inputs use 16px mobile text to prevent focus zoom; pinch zoom remains enabled. Next continues to own routes, document scrolling and existing drawers; Ionic's global layout/typography resets and router are deliberately not installed.

Verification: check a mobile browser and installed iPhone/Android app in portrait/landscape, light/dark appearance, visible/dismissed demo banner, and keyboard open. Confirm toolbar controls remain accessible, no horizontal overflow, fullscreen menus retain close controls, and browser/OS status-bar areas do not cover content. Desktop should keep its established density. Browser previews do not reproduce real notch/status-bar insets. No API, database or network-boundary changes are involved.

Reference: [Ionic platform modes](https://ionicframework.com/docs/theming/platform-styles).

Navigation and account drawers always use a local dark theme, including their nested text, controls, active/hover states and native form colour scheme. Switching the page to light mode preserves the same drawer appearance without changing the rest of the page theme.

Only the collapsed navigation rail uses the muted blue gradient and brighter hover surface in both themes. Expanded drawer navigation and other dashboard controls retain their established styling.

The toolbar search keeps its compact 36px height, 12px desktop text and subtle blue focus treatment independently of Ionic toolbar typography.

Toolbar autocomplete escapes Ionic toolbar clipping and appears above page content, with a viewport-bounded scrolling list. Full-screen overlays retain their higher stacking level.

An active toolbar search dropdown dims the page with a lightbox backdrop (35% black in light mode, 45% in dark mode). The header and suggestions remain above it; clicking outside or pressing Escape dismisses suggestions and the mask together.

Navigation chrome uses a dark blue-grey gradient (#283544 to #1a2634) in both themes. Dark-theme popup surfaces use matching slate tones rather than near-black, while light-theme popups retain their light surfaces.

The expanded sidebar collapse control matches the collapsed rail expand control: circular blue gradient, matching outline and hover treatment.

The responsive widget editor device selector uses a 32px container with full-height buttons and no extra bottom padding.

Expanded navigation rows no longer draw a vertical separator beside the child-menu expand/collapse control.

The top-bar logo has a soft blue artwork-shaped glow on hover or keyboard focus, with a stronger glow and subtle press feedback when clicked.

On mobile, the top-bar logo artwork matches the 44px navigation controls. Top-bar controls share a blue-tinted hover and keyboard-focus shadow in both colour modes.


Configure widgets uses the shared primary blue gradient icon-button style in both colour modes.


The SQL Bridge refresh-status badge uses the same compact 32px minimum height and small text as the adjacent refresh controls.


The navbar notification bell always displays the unread, unarchived count, including zero, capped visually at 99+. Its accessible label includes the full count.


The notification count badge uses a red background with white text in both colour modes.


The notification bell briefly swings when a new unread, unarchived notification ID arrives. Initial rendering, read/archive changes and repeated refreshes of existing items do not ring it; a new arrival restarts the animation.


The theme toggle rotates and scales its sun/moon icon into view when the selected theme changes, retaining the current button dimensions and accessible action label.

The theme-toggle and notification-arrival animations run even when the device requests reduced motion, as explicitly requested for these controls.


The theme toggle now gently crossfades and reshapes the sun/moon artwork, with no rotation or movement of the button itself.


The theme icon uses an SVG crescent mask: the sun's rays fade as the disc becomes a moon, with a 380ms Web Animations transition independent of stylesheet motion overrides. The button stays stationary.


The navbar mounts the notification menu immediately on page load, rather than replacing a lazy placeholder after the first click. The red unread-count badge and arrival animation use the same component throughout.


The bell glyph remains unframed when its count badge is present. Desktop notification popups use up to 640px of height, bounded by the viewport, with a scrolling list and fixed header/footer; mobile remains fullscreen.


The bell explicitly clears inherited SVG background, border and padding so its count badge cannot trigger a second icon frame.


The red notification counter has fixed equal 20px dimensions and no padding, keeping it circular for all displayed counts.


The command palette uses the same blue-grey surface theme in both light and dark app modes, with locally scoped dark control styling and matching result/detail panels.


Command-palette results emphasise object names with brighter semibold text, clearer source context and a blue database chip, while timestamps remain secondary. Selected results have a stronger blue edge.


The command palette uses liquid-glass blue layers: a translucent blurred shell, soft specular borders, inset search field, glass filters and result cards, and a translucent detail pane. The palette keeps readable text, scrolling regions and fullscreen mobile layout in both app themes.


On desktop, the command-palette mode tabs float centrally across the panel's top edge, with space reserved above the search field. Mobile retains its in-panel top controls.


Desktop keyboard shortcuts float centrally across the command palette's bottom edge, matching the top mode tabs. They stay hidden on phone layouts to preserve results space.


Dashboard recovery screens use a neutral glass-style panel, a primary retry action and expandable technical details instead of a full red error card. Command-palette loading placeholders no longer reference result-view state outside their component scope.


All shared page-introduction documentation links and buttons match their adjacent introduction toggle at 30px square, with matching icon size, padding and corners, regardless of link or button semantics.

Expanded navigation uses consistent 13px labels and larger 28px route icons. Overflowing labels scroll to reveal their full text while their link is hovered or keyboard-focused, then return to the start when leaving. Labels that fit remain still.

Workspace tabs use compact 144px widths and scroll overflowing titles on hover or keyboard focus, leaving the icon and close control fixed.

The collapsed navigation rail's expand control is centred within the measured navbar height, aligning it vertically with the toolbar logo instead of using fixed top padding.


The expanded menu header also uses the measured navbar height so its logo and collapse control align with the toolbar controls.


The collapsed menu no longer includes the redundant bottom SC home shortcut; the toolbar logo remains the dashboard link.


On touch/mobile layouts, menu help opens a native modal dialog with close/backdrop dismissal and focus restoration; desktop hover help remains. Command-palette mode tabs show their icons on phones. Object filters measure the available width and keep one row, moving overflow entries into More without hiding their selection options.


The floating shortcuts bar rests at 70% opacity, returns to full opacity on hover or focus within, and uses a pointer cursor.


The floating shortcuts bar omits the Copy Actions hint.

All object types are eligible for the command-palette filter row, in common-first order. The row shows as many as fit and reserves More only when types remain; More disappears when all types fit.


Filter fitting measures real buttons with their inherited typography rather than smaller spans, so the overflow calculation matches the visible control widths. The hidden measurement row is clipped to avoid contributing page overflow.


The desktop command palette defaults to 30% results / 70% details. Its divider snaps in 5% steps between 30/70 and 70/30, supports arrow keys and Home/End, and resets to 30/70 on double-click. Neither pane can shrink below 30% of the available pane width.


The desktop split divider has a highlighted drag grip and visible 30/70, 50/50 and 70/30 preset buttons; the current preset is highlighted. All presets retain the 30% minimum per pane.


Command-palette result cards omit the Matched on preview line, keeping the object identity and metadata without repeated match explanations.


Object result cards also omit the duplicate type/server/database/schema summary line, retaining the individual metadata rows below the object name.


Result attributes use consistent glass-highlighted chips with icons for server, database, schema, parent and modified date. Database chips receive stronger emphasis, while dates stay secondary; long values wrap within the results pane.


Split presets use proportional two-column icons instead of numbers, retaining exact ratios in tooltips and accessible labels.


Split preset controls rest at 70% opacity and return to full opacity on hover or keyboard focus within.


Command-palette scope labels sit above their selects. A Workspace selector lists the existing authorized workspace options and filters only the search, without switching active workspace or reloading. Desktop shows three columns; narrow phones place workspace above instance/database.


### Search-only workspace scope

The command palette Workspace dropdown changes only local search criteria. It does not call `/api/workspace/switch`, save `activeWorkspace`, or reload the page. Instance/database selections, old results and detail are cleared when the search scope changes. Cached status/recent lists are keyed by selected workspace and superseded responses are ignored.

Authenticated GET `/api/object-search/status`, `/api/object-search/search`, `/api/object-search/recent` and `/api/object-search/objects/{id}` accept optional `workspace=personal:personal`, `personal:<workspaceId>` or `team:<teamId>`. Without it, existing active-workspace scope applies. Status requires `objectSearch.view`; the other reads require `objectSearch.search`. The auth store resolves ownership/team membership before the server generates the index workspace key. Raw `workspaceKey` remains rejected. Invalid selectors return 400, unauthorized workspaces 403; no fallback widens access. Response envelopes remain unchanged; `/openapi.json` and `/api-docs` describe the parameter.

Risk: indexed metadata must never cross workspace authorization boundaries. Safe verification: search an owned personal workspace and a member team, verify non-member/foreign selections fail, and confirm the active-workspace preference is unchanged. This reads the existing object index; it opens no customer SQL connections and adds no persisted settings.

The command-palette summary displays Last workspace sync using the newest successful source-sync timestamp within the selected workspace. It does not reuse the runtime's global last-run completion time; loading and no-success states are explicit.


SQL definition previews use a monospace SQL code block with keyword, type, string, comment, number and variable highlighting. Original whitespace and copy content are preserved, with horizontal scrolling for long SQL lines; search-term highlighting remains available.


Result attribute boxes fill the metadata column width. Detail lists expand from the More button to at most 1,000 items, offer Show less, and display an explicit truncation notice for longer lists; reference expansion resets when selecting a different object.


The command-palette search field has one glass border and wrapper focus ring; the input itself has no nested outline. An inline clear button appears when text is entered, clears only the query and returns focus to the input.


The command-palette close control matches drawer close styling, with a blue hover surface, rotating X, slight hover enlargement and press feedback, including when reduced motion is selected as requested.


Object detail sections use an icon-led tab bar connected to the content panel below. Active tabs have an underline and shared surface; arrow keys and Home/End move focus and selection, with one tab in the keyboard tab order.



### Demo banner in installed apps

The demo notice shares the slate toolbar surface, including the iOS status-bar safe area. Amber is limited to the demo title; the read-only explanation stays legible and the acknowledgement button has a separate touch target. Dismissing the notice transfers top safe-area padding back to the toolbar. Demo restrictions and settings are unchanged. Verify in an installed iOS PWA with the notice visible and dismissed, and with navigation/account drawers open.
