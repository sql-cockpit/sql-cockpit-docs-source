# Workspaces

`/workspaces` lists every workspace available to the signed-in account: the default personal workspace, account-owned personal workspaces, and team workspaces from active team memberships. Legacy `/teams` links redirect to `/workspaces`.

The table uses `GET /api/workspaces`, switching rows calls `POST /api/workspace/switch`, and clicking a row expands a read-only operational summary from `GET /api/workspaces/summary`. Team workspace options from `GET /api/workspaces` include active member display metadata and optional `profilePicture` avatar values so the Welcome Page **Active Workspace** widget can show member avatars. The summary resolves the selected workspace through server-side membership checks and shows object-search cache counts, estimated cache size, saved profile counts, task/job counts, next scheduled jobs, running runs, and recent runs without changing the active workspace. Task/job details are included only for users with `tasks.view`. Team rows expose an inline invite form backed by `POST /api/teams/{teamId}/invites`. The invite form asks for email and an optional message only; expiry comes from the system setting. Team membership and private workspace creation remain on `/account`. The **Join a team** selector on `/account` only lists teams with a pending, unexpired invite for the signed-in user's email address.

## Storage

- Active selection: `user_preferences.activeWorkspace`.
- Account workspaces: `workspaces.owner_user_id`.
- Team workspaces: `workspaces.team_id`.
- Joinable team list: `team_invites` rows with `status='pending'`, a future `expires_at`, and `invited_email` matching the user email. Legacy users without `users.email` also match email-shaped display names or usernames.
- Created invites: `team_invites`; duplicate pending invites and active member emails are rejected.
- Invite expiry: `settings.teamInvites.defaultExpiresInHours`, or env fallback `SQL_COCKPIT_TEAM_INVITE_EXPIRES_IN_HOURS`, default `168`, valid range `1..720`.
- Default personal workspace: virtual option with no required `workspaces` row.

## Safe Test

1. Open `/workspaces` as a user with personal and team access.
2. Confirm both personal and team rows are listed.
3. Click a workspace row and confirm the expanded summary shows cache, profile, and task/job details for that row without switching the active workspace.
4. Switch to another workspace and confirm it becomes current.
5. Open `/teams` and confirm it redirects to `/workspaces`.
6. Open `/account` and confirm **Join a team** only shows invite-backed teams.
7. Invite a non-member email from a team row on `/workspaces`, then retry with an active member or duplicate pending email and confirm validation blocks it.
