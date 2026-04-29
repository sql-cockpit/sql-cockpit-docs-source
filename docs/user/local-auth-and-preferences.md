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
- notification read and archive state
- saved database connection profiles
- saved SQL Server instance profiles
- account-owned workspaces created from the Account page

That means these values no longer depend on one browser profile alone. They now follow the signed-in SQL Cockpit user on that machine.

## Account workspaces

Signed-in users can create additional private workspaces from the dashboard header or the Account page.
Each account workspace has its own saved connection and instance profile lists.
The default `My Workspace` remains available for existing personal profiles.
Users can create more than one account workspace, including multiple workspaces with the same display name when the slug field is left blank. SQL Cockpit derives a distinct slug for each workspace, such as `support`, `support-2`, and `support-3`.
Changing workspace also changes the command palette search environment. Object-search syncs, manifests, locks, recent objects, search results, and object definition lookups are scoped by the active workspace, so databases must be synchronized separately in each workspace where you want them searchable.

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
