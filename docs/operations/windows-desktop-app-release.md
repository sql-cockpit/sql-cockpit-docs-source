# Windows Desktop App (Electron) Release

This runbook covers building and publishing the SQL Cockpit desktop app with GitHub Releases and `electron-updater`.

## Build system

The desktop app uses the same build flow as the Service Control app:

- timestamped output directory per build
- `electron-builder` with NSIS installer
- GitHub Releases for auto-updates

Build script:

- `webapp/electron/build/run-electron-builder.js`

## Release workflow

GitHub Actions workflow:

- `.github/workflows/release-desktop-app.yml`

Release tags:

- `desktop-vX.Y.Z`

## Local build (installer)

```powershell
Push-Location .\webapp
npm ci
npm run build
npm run dist:desktop
Pop-Location
```

The script prints the final installer path:

```
Installer path: <...>\desktop-YYYYMMDD-HHMMSS\SQL Cockpit setup.exe
```

## Portable build (dev master exe)

Use the portable build when you want a single EXE for dev/testing. Note that auto-updates do **not** work for portable builds.

```powershell
Push-Location .\webapp
npm run dist:desktop:portable
Pop-Location
```

Run with dev mode:

```powershell
.\desktop-publish\desktop-YYYYMMDD-HHMMSS\SQL Cockpit portable.exe --dev
```

## Auto-updates

Auto-updates require the installed (NSIS) build. They use:

- `electron-updater` inside `webapp/electron/main.js`
- GitHub Releases configured in `webapp/package.json`

Operational notes:

- updates are checked on app start when packaged
- portable builds do not auto-update

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| update check skipped | app not packaged | expected in dev/portable builds |
| update not found | tag mismatch | use `desktop-vX.Y.Z` and ensure package version matches |
| installer fails to publish | missing token | ensure `GITHUB_TOKEN` is available in Actions |
