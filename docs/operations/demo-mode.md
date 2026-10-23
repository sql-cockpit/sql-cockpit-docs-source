
## Safe exploration controls

Demo presentation explicitly enables reviewed Welcome Page navigation cards, account/workspace/preferences navigation, tab scrolling and local new tabs, plus pure task/schedule validation. Opening a page does not grant its write permissions. Labels such as Notifications and pagination are recognized as UI browsing. All backend endpoint, RBAC, store and Agent restrictions remain unchanged: validation cannot schedule or run tasks, and SQL execution, saved configuration changes, service control and ingestion remain blocked. Unknown controls still default to unavailable. No new flags or persistence are introduced.

Safe check: sign into the demo, open widget links and drawer panels, scroll/create local tabs and inspect existing records. Check pure validation where the composer is authorized; confirm Save, Run, Sync and service actions remain unavailable and direct mutation requests still return the demo 403. UI changes remain in memory only.

## Public administrator exploration entry

In the isolated synthetic demo, the login page can show “Here to try the demo?” with “Login as administrator”. The browser posts `{ "demoAdministrator": true }` to the existing `POST /api/auth/login`. The server substitutes its protected configured local administrator credential and runs normal local authentication and lockout checks; no credential is shipped in JavaScript, HTML, auth status or the response. Successful response remains `{user}` plus the existing HttpOnly session cookie. Invalid configuration returns 403; failed credentials return 401. Normal username/password sign-in remains available.

`GET /api/auth/status` adds `demo: {enabled, administratorLoginAvailable}` booleans. Both operations remain unauthenticated entry points; ordinary Origin checks and authentication throttling are retained. Administrator access exposes more of the synthetic demo's readable configuration to visitors, but the independent demo policy continues to block all persistent feature changes, SQL execution, service actions and unclassified routes, even for this administrator session. Never enable this feature on a tenant with non-synthetic data.

Settings (database storage: none):

| Environment setting | Values / default | Effect and risk |
| --- | --- | --- |
| `SQL_COCKPIT_DEMO_ADMIN_LOGIN_ENABLED` | Exact `true` enables; absent/other values disable | Opts into public administrator exploration; also requires exact enabled synthetic Demo Mode and a validated reader account. |
| `SQL_COCKPIT_DEMO_ADMIN_USERNAME` | Existing local account name, 3–64 letters/digits/dot/underscore/hyphen; no default | Selects the existing administrator. A non-admin authentication result is revoked and denied. |
| `SQL_COCKPIT_DEMO_ADMIN_PASSWORD` | Existing protected credential, minimum 16 characters; no default | Server-only input to normal local authentication. Never put in frontend environment variables, logs, source or documentation. |

OVH configuration writes these fields only for Demo Mode into the protected existing `/srv/sql-cockpit/config/api.env`, using the already provisioned administrator username/password. Ordinary deployment sets the flag false and omits the credential fields. It does not reset or create accounts. New settings take effect after deployment/restart. To disable public entry, remove/disable the flag and restart; normal administrator authentication remains. This public demo feature does not change session persistence providers or tenant scoping.

Safe test: run `node --test tests/demo-mode.test.js` in the API. Test the button against an isolated synthetic demo; verify status and responses contain no credential, a session cookie is HttpOnly, mutation/SQL calls still return demo 403, and non-demo or missing-configuration entry returns 403. Review public admin-readable content before enabling. No live credential is needed for automated tests.

OVH serializes the private credential as `SQL_COCKPIT_DEMO_ADMIN_PASSWORD_BASE64` (base64 of the UTF-8 password; no default) to prevent Compose from interpolating dollar signs or special characters. This is encoding, not encryption: protect it like the original password. It takes precedence over the plain environment input; neither value is exposed to the client.
