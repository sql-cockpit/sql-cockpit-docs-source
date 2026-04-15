# Documentation Screenshots

Yes, automated screenshots fit this docs set well.

The app is visual enough that pages like `Instance Manager`, `Connection Manager`, `Estate Overview`, `Fleet`, and `SQL Agent Manager` are easier to understand with current screenshots beside the written steps.

## Approach

Use automated browser screenshots rather than manual screenshots so that:

- images stay consistent in size and naming
- stale UI images are easier to refresh
- the docs can capture the real local app instead of mocked layouts
- maintainers can regenerate screenshots after UI changes

## Current Support

This repo now includes a screenshot script:

```text
docs/scripts/capture-doc-screenshots.mjs
```

The script reads a manifest:

```text
docs/screenshots/pages.json
```

And writes images to:

```text
docs/assets/screenshots/
```

When the manifest entry includes `docsTargets`, the same script also updates the matching markdown pages with generated screenshot blocks.

## Usage

1. Start the local app workspace or REST host so the dashboard is reachable.
2. Confirm Playwright can launch Chromium on the workstation.
3. Set screenshot credentials for a local SQL Cockpit account.
4. Run the screenshot script from the repo root.

Prefer environment variables so the password does not end up in command history:

```powershell
$env:SCREENSHOT_USERNAME = "docs_screens"
$env:SCREENSHOT_PASSWORD = "replace-with-local-screenshot-password"
node .\docs\scripts\capture-doc-screenshots.mjs --base-url http://127.0.0.1:8080
```

```powershell
node .\docs\scripts\capture-doc-screenshots.mjs `
  --base-url http://127.0.0.1:8080 `
  --username "docs_screens" `
  --password "replace-with-local-screenshot-password"
```

Optional flags:

```text
--manifest <path>
--output-dir <path>
--login-path <path>
--timeout-ms <number>
--username <username>
--password <password>
--capture-only
--sync-docs-only
```

Behavior:

- default: the script signs in once through `/login`, keeps the authenticated browser context, captures each page from the manifest, and updates linked markdown blocks
- default: capture screenshots and sync linked markdown blocks
- `--capture-only`: capture images without editing docs pages
- `--sync-docs-only`: update markdown blocks using the expected image paths without recapturing
- manifest entries default to `requiresAuth: true`; set `requiresAuth: false` on an entry only when the page is intentionally public

## Authenticated Capture

The dashboard now requires local sign-in before the documentation pages in `docs/screenshots/pages.json` can render useful screenshots.

The screenshot script now:

- reads credentials from `SCREENSHOT_USERNAME` and `SCREENSHOT_PASSWORD` by default
- accepts `--username` and `--password` overrides when needed
- signs in once at `/login?returnTo=/`
- fails fast if the app redirects to `/setup`, or if the browser falls back to `/login` while trying to capture a protected page

## Recommended Screenshot Account

Use a dedicated low-risk local SQL Cockpit account or a dedicated screenshot auth-store snapshot for docs capture.

Practical guidance:

- keep screenshot capture on a local or otherwise sanitized environment only
- use stable instance and connection profiles with non-sensitive names
- avoid pages that show live SQL-auth usernames, passwords, or business-sensitive object names
- prefer a separate screenshot workstation or a resettable local auth database when the current environment only exposes one bootstrap user
- review every generated image before committing it

Current limitation:

- confirmed: the current UI exposes first-run setup for the initial local account and sign-in for existing accounts
- uncertain: whether your environment includes an additional user-management path outside the main UI for creating a dedicated screenshot-only account

## Stable Output

To keep screenshots repeatable:

- seed the same local auth store and saved profile set before each capture run
- keep the dashboard on the same viewport and route order used by the script
- avoid capturing transient toast messages, live alerts, or rapidly changing operational pages unless they are intentionally staged
- re-capture after meaningful layout or navigation changes so image placement stays aligned with the docs

## Safe Use Notes

- Only capture low-risk demo or sanitized environments.
- Avoid pages that display SQL-auth credentials, sensitive server names, or business-sensitive object names.
- Review generated images before linking them into user-facing pages.
- Re-capture after material dashboard layout changes so the docs and UI stay aligned.

## Suggested First Targets

- `/`
- `/instance-manager`
- `/connection-manager`
- `/server-explorer`
- `/agent-manager`
- `/fleet`
- `/inspector`

## Confidence

- confirmed: the repo already contains Playwright in the installed dependency graph
- confirmed: the dashboard is served locally through the Node host
- confirmed: authenticated screenshot capture now requires dashboard credentials and signs in through the local login page before capture
- inferred: some routes may need seeded local profile data or reachable SQL targets to produce useful screenshots
- uncertain: whether every maintainer workstation already has Playwright browser binaries installed
