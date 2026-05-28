# Admin Users

The Users admin menu is split into focused pages:

| Route | Purpose | Authentication/RBAC |
| --- | --- | --- |
| `/admin/users` | Review local users and open a focused edit page for a selected account. | `users.view`. |
| `/admin/users/create` | Create a local SQL Cockpit user account. | `users.create`; existing users are shown when `users.view` is also available. |
| `/admin/users/edit?userId=<id>` | Edit profile state, roles, teams, passwords, and linked identities for one user. | `users.view`; write actions require the matching API permissions. |

Operational notes:

- User records live in the local SQLite `users` table.
- `/admin/users` no longer includes create-user or edit-user forms.
- `/admin/users/create` posts to `/api/admin/users` and then clears the form.
- User list `Edit` actions navigate to `/admin/users/edit?userId=<id>`.
- No database flags or settings are added by this route split.

Safe test:

1. Open `/admin/users` and confirm create/edit forms are absent.
2. Click `Edit` for a user and confirm `/admin/users/edit?userId=<id>` opens.
3. Open `/admin/users/create` and create a non-admin test user.
4. Return to `/admin/users` and confirm the user appears in the list.
