# Admin Workspaces

The Workspaces admin menu is split into focused pages:

| Route | Purpose | Authentication/RBAC |
| --- | --- | --- |
| `/admin/workspaces` | Review all personal and team workspaces, owner or team context, and active/inactive members. Search, type/status filters, and sortable headers run client-side over the loaded table. | `teams.view`; dashboard route is local-admin gated. |
| `/admin/workspaces/create` | Create a local team and matching shared workspace. | `teams.create`. |
| `/admin/workspaces/invites` | Review invite history across all teams; create or revoke invites when permitted. | Viewing requires `teams.view`; create/revoke requires `teams.assign_members`. |

Legacy `/admin/teams*` routes redirect to the matching `/admin/workspaces*` routes.

Operational notes:

- Workspace rows live in `workspaces`; personal rows use `owner_user_id`, while team rows use `team_id`. Sorting and filtering on `/admin/workspaces` are client-side over `/api/admin/workspaces`.
- Team records live in `teams` and team memberships come from `team_memberships` joined to `users`.
- Invites live in `team_invites`; `/admin/workspaces/invites` reads `/api/admin/team-invites` so local admins can see every invite made in the system.
- No database flags or settings are added by this route rename.

Safe test:

1. Open `/admin/workspaces` and confirm personal and team workspaces are listed.
2. Confirm personal owner names and team member counts are visible.
3. Test search, type/status filters, and sortable headers.
4. Open `/admin/teams` and confirm it redirects to `/admin/workspaces`.
5. Open `/admin/workspaces/create` and `/admin/workspaces/invites`.
