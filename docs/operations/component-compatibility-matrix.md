# Component Compatibility Matrix

Use this page to declare cross-repository runtime compatibility before publishing new releases.

## Matrix

| Service Control version | Minimum API version | Minimum Desktop version | Minimum Object Search version | Notes |
| --- | --- | --- | --- | --- |
| 1.0.3 | 1.0.0 | 1.0.0 | 1.0.0 | Initial split-era baseline with repo-root token support and orchestrator scripts. |

## Update rules

1. Update this matrix in the same PR as any component release that changes:
   - service settings keys
   - startup arguments
   - health endpoint contracts
   - token expansion behavior
2. Do not publish `service-control` without a declared minimum API/Desktop/Object Search version.
3. If a release is incompatible with older versions, add explicit rollback notes.
