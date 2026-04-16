# Platform Components

This page is the operator-facing component map for SQL Cockpit.

## Components at a glance

| Component | What it does | Typical owner | Default endpoint |
| --- | --- | --- | --- |
| SQLCockpitServiceHost | Starts/stops and monitors runtime components | Windows SCM (`SQLCockpitServiceHost`) | `http://127.0.0.1:8610/` |
| Web API | Serves SQL Cockpit API + dashboard routes | Service host component manager | `http://127.0.0.1:8000/` |
| Docs server | Serves MkDocs content for local help | Service host component manager | `http://127.0.0.1:8001/` |
| Notifications server | Emits runtime notification stream | Service host component manager | `http://127.0.0.1:8090/` |
| Object search service | Hosts Lucene index/search API | Service host component manager | `http://127.0.0.1:8094/` |
| Service Control app | Operator UI to control service/components | User session app | connects to `:8610` |
| Desktop UI app | End-user SQL Cockpit desktop shell | User session app | connects to `:8000` |

## Normal startup sequence (production profile)

1. Windows starts `SQLCockpitServiceHost`.
2. Service host starts managed components (`web-api`, `docs`, `notifications`, `object-search`).
3. User launches Service Control and/or Desktop UI.
4. Desktop UI connects to API on `:8000`.

## Troubleshooting ownership conflicts

- If `:8000` is already in use, identify which process owns it before launching/restarting API.
- Do not run two owners for the same endpoint.
- In production profile, prefer service-host ownership for API and side services.
- Keep Desktop UI in user session; do not try to run desktop window lifecycle under SCM.
