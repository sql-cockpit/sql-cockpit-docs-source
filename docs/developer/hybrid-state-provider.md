# Hybrid state provider

The auth stores expose deployment-only demo persona provisioning and read-only persona validation through an injected adapter for both SQLite and Azure SQL. It uses the existing provider's tenant database and workspace/user membership tables; no route-layer or customer-database persistence paths are added. See [Demo Mode](../operations/demo-mode.md#standard-user-demo-personas) for secret storage, idempotence and safe deployment verification.
