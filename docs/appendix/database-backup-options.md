# Download a database backup

From Estate Overview, open a database's action menu and choose **Backup database**. The instance and database are selected automatically. Choose compression and click **Create backup**, then confirm. When the Agent finishes creating and verifying the backup, choose **Download .bak file**.

Phase 1 supports full copy-only backups with checksums. SQL Server must run on the Agent host, used data and backup file must fit within 256 MiB, and at least 1 GiB of staging disk must be free. The Agent uses SQL Server's default backup directory. The SQL Server account needs backup permission and the Agent needs access to the staged file. Your SQL Cockpit account needs database backup view/create permissions.

The temporary download is available for one hour. API or Agent restart invalidates it; create a fresh backup if it expires. Downloads contain database data: protect the file and check the SHA-256 shown on the page. Verification is not a substitute for a test restore. No restore operation is provided.

Only compression is configurable in this phase. Differential/log backups, custom server destinations, scheduling, remote SQL Server file transfer and hosted tenant downloads are not implemented. Existing Object Backups archive definitions and remain a separate feature. The workflow never opens SQL connections from the browser or hosted API.
