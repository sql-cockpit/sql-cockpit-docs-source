# AutoPilot conversations

Open **AutoPilot** to find your recent conversations and continue chatting. Use the search box to filter by conversation title, select a chat to reopen it, or choose **New conversation**. New replies are saved automatically, including replies from Ask AutoPilot in the search palette.

Your saved chats are private to your account within the selected workspace. Up to 20 recent conversations are retained for 30 days, with bounded excerpts of long answers, SQL and tables. Check the save-status message before closing a chat. Conversations closed before history was introduced cannot be recovered.

To remove a history entry, choose **Delete** and confirm. Reopened answers are historical snapshots; follow-ups use your current permissions and database scope. Ask again for fresh information when metadata has changed. Avoid entering passwords or other sensitive information.

## Conversation names and controls

Recent chat cards have a top-right bin button with explicit deletion confirmation and an adjacent actions dropdown with Rename conversation. Refresh includes a refresh icon. Rename opens a labelled dialog with Cancel and Save name; titles must contain 1–100 characters after trimming. Failures keep the dialog open for retry.

`PATCH /api/autopilot/conversations/{id}` accepts `{title,scopeToken}` and returns the conversation summary. It requires an active session and `objectSearch.search`, derives tenant/environment/workspace/user on the server, and checks the current scope token (409 on mismatch). Invalid titles return 400; unavailable/cross-owner IDs return 404. Titles use the existing history redaction. No SQL or inference runs. The existing provider-backed history bucket stores the title; transcript version, messages, scope and retention timestamp remain unchanged, so an in-progress chat can save normally and keeps the custom name.

Safe verification: run `node --test sql-cockpit-api/tests/chat-history.test.js` for rename/continuation, validation and scope isolation. In Dev, open Rename and cancel; use a disposable conversation to test saving and reloading a name. Confirm its transcript remains. No new flags or storage schema are introduced.

Demo Mode keeps its central API read-only policy. Conversation creation, rename and deletion must not be presented as available there; administrator roles do not bypass the policy. Normal-installation history behavior described above is not a demo permission grant.
