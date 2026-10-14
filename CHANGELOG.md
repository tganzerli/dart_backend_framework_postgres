# Changelog

## 0.1.2

Consumed by `git` reference to the tag `v0.1.2`. Depends on `dart_backend_framework` 0.1.0 and
`dart_db_connector_postgres` 0.1.3.

### Added

- `prefixTsQuery(input)`: a prefix `tsquery` (`'jo':* & 'sil':*`) from free text, for
  `to_tsquery(config, $1)` with `Param.text`. Only letters, combining marks and digits survive; operators, quotes and
  backslashes are separators. Returns `null` when there is no word.

### Changed

- The package is described as the PostgreSQL kit for applications that use the framework with the connector.
- The connector dependency moves to 0.1.3 (from 0.1.1), so this kit and the connector at 0.1.3 can be used together.
  Through the connector, `tsvector`, `tsquery` and `regconfig` values now read as `String`; see its CHANGELOG.

### Tests

- The integration tests no longer point to a directory outside the package; their header and the README "Tests"
  section say which PostgreSQL they expect.
- Operator-injection tests for `prefixTsQuery`, without a database and against PostgreSQL.
- A public-surface test over the package barrel.

## 0.1.1

Consumed by `git` reference to the tag `v0.1.1`. Depends on `dart_backend_framework` 0.1.0 and
`dart_db_connector_postgres` 0.1.1.

- No code change. The connector dependency moves to 0.1.1, so this extension and the connector at 0.1.1 can be
  used together; on 0.1.0 they conflicted in `pub get`.

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
