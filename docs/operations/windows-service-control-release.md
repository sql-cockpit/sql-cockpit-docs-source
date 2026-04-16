# Windows Service Control Repo Release Runbook

This runbook documents how to update and publish a new version of the separate SQL Cockpit Service Control Electron repository.

Repository:

- `https://github.com/jjmpsp/sql-cockpit-servicemanager`

Local path used in examples:

- `C:\Scripts\SQL Tables Sync\service`

## Purpose

Use this process when you need to:

1. update release workflow or updater configuration
2. bump app version
3. publish a new GitHub Release so `electron-updater` clients can download it

## Prerequisites

1. You can push to `main` and create tags in `sql-cockpit-servicemanager`.
2. The repository contains:
   - `.github/workflows/release-electron.yml`
   - `windows/SqlCockpit.ServiceControl.Electron/package.json`
3. `windows/SqlCockpit.ServiceControl.Electron/package.json` has the correct publish target:
   - `owner: jjmpsp`
   - `repo: sql-cockpit-servicemanager`
4. You use semantic versions and tags (`vMAJOR.MINOR.PATCH`, for example `v1.0.1`).
5. Installer runtime prerequisites are documented and validated in ops notes:
   - elevated install required
   - `dotnet` SDK required for service-host provisioning during installer post-install

## Standard release flow (authoritative commands)

Run in PowerShell from `C:\Scripts\SQL Tables Sync\service`:

```powershell
git add .github/workflows/release-electron.yml windows/SqlCockpit.ServiceControl.Electron/package.json README.md
git commit -m "Add GitHub Releases workflow for Electron app"
git push origin main
git tag v1.0.1
git push origin v1.0.1
```

Important:

- replace `v1.0.1` with your next version tag
- keep the tag and `package.json` version aligned

## Safe release procedure

1. Edit version and metadata first.
   - update `windows/SqlCockpit.ServiceControl.Electron/package.json`
   - confirm `build.publish.owner` and `build.publish.repo`
2. Commit and push the source changes to `main`.
3. Create and push one release tag.
4. Open GitHub Actions and confirm `Build And Publish Electron App` succeeded.
5. Open the GitHub Release and confirm required assets exist (installer plus updater metadata files).
6. Validate from an installed app using `Check For Updates`.

## Versioning rules

1. Patch (`1.0.0` -> `1.0.1`): fixes only.
2. Minor (`1.0.1` -> `1.1.0`): backward-compatible features.
3. Major (`1.1.0` -> `2.0.0`): breaking changes.

Tag format must stay:

- `v1.0.1` (leading `v` required by workflow trigger)

## Post-release validation checklist

1. GitHub workflow run finished with green status.
2. Release includes generated installer assets.
3. Release includes updater metadata (`latest*.yml`/blockmap where applicable).
4. A packaged Windows client can:
   - detect update
   - download update
   - install and restart successfully
5. Service control functions still work after update:
   - read service status
   - list components
   - start/stop/restart actions

## Troubleshooting

### Tag push did not trigger workflow

Likely cause:

- tag does not match `v*.*.*`

Action:

- create a valid semver tag and push it.

### Updater does not find releases

Likely causes:

- `build.publish.repo` mismatch
- release artifacts missing updater metadata

Action:

1. verify `windows/SqlCockpit.ServiceControl.Electron/package.json`
2. verify release assets were produced by workflow
3. publish a corrected version with a new tag

### Workflow succeeds but no release assets

Likely cause:

- build command or working directory mismatch

Action:

1. verify workflow working directory:
   - `windows/SqlCockpit.ServiceControl.Electron`
2. verify script:
   - `npm run dist`
3. rerun after correction with new tag

## Rollback guidance

If a bad release is published:

1. keep the bad tag immutable (do not retag the same version)
2. publish a newer fixed version (for example `v1.0.2`)
3. if needed, mark the bad GitHub release as not recommended in release notes

Operational risk note:

- deleting or rewriting already-published release tags can cause inconsistent updater behavior across installed clients.
