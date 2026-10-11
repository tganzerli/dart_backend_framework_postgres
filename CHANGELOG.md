# Changelog

## 0.1.0

First public release, consumed by `git` reference to the tag `v0.1.0`. Depends on `dart_backend_framework`
0.1.0 and `dart_db_connector_postgres` 0.1.0.

- `rlsTransaction` / `rlsTransactionOn`: one transaction per request with the tenant set by a parameterised
  `set_config` as its first statement; commit before the response is written (buffered body) or after the last
  byte (stream); rollback on exception, on a status of 400 or above (`shouldCommit`, default `commitOnSuccess`)
  or on `setRollbackOnly()`; `onUnresolved` without borrowing a connection when there is no tenant; `503` with
  `Retry-After` when the pool is exhausted.
- `RlsException`, `RlsContextException`, `RlsCommitException`.
- Example CRUD server in `example/`.
