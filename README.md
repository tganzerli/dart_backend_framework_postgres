# dart_backend_framework_postgres

PostgreSQL kit for [`dart_backend_framework`](https://github.com/tganzerli/dart_backend_framework),
for applications that use it together with
[`dart_db_connector_postgres`](https://github.com/tganzerli/dart_db_connector_postgres).
The framework has no database dependency; this package holds the
PostgreSQL-specific pieces for using the two together: a per-request RLS
transaction (`rlsTransaction`) and a prefix search builder (`prefixTsQuery`).

**Experimental, not on pub.dev yet.** Install by `git` reference to a tag; the
framework and the connector come with it:

```yaml
dependencies:
  dart_backend_framework_postgres:
    git:
      url: https://github.com/tganzerli/dart_backend_framework_postgres
      ref: v0.1.2
```

The connector ships its native library pre-built and needs `libpq` at run time;
see its README for AOT and container builds.

## `rlsTransaction`: one RLS transaction per request

```dart
final handler = Pipeline()
    .add(authenticate())                       // yours: puts the principal in the context
    .add(rlsTransaction(
      pool: pool,
      tenantResolver: (request) => request.context.getOrNull<Principal>()?.tenantId,
      onUnresolved: (_) => Response.forbidden(),
    ))
    .addHandler(router.handler);

// In a handler:
final rows = await request.rls.executor.execute('SELECT ...');
```

Per request the middleware borrows a connection through `PostgresUnitOfWork`,
runs `SELECT set_config($name, $tenant, true)` (both bound as parameters) as the
first statement of the transaction, hands the handler an executor pinned to that
transaction, and ends it deterministically. The connection always goes back to
the pool, from a cleanup hook if nothing else did.

### What ends the transaction

| Situation | Outcome |
|---|---|
| Buffered body, status below 400 | `COMMIT` **before** the response is written, so a failing commit becomes an error response, never a 200 already sent |
| Buffered body, status 400 or above | rollback (predicate `shouldCommit`, default `commitOnSuccess`) |
| Handler throws | rollback, then the error reaches the error boundary |
| `request.rls.setRollbackOnly()` | rollback, whatever the status |
| `Stream` body | decided after the handler, applied by the cleanup hook **after the last byte**, so the stream can keep reading through the executor |
| No tenant (`null` or empty) | `onUnresolved`; no connection is borrowed, no `next()` |
| Pool exhausted | 503 with `Retry-After: 1` (`onUnavailable`) |

### Rules this package cannot enforce

- **Streamed routes under RLS must be read-only.** A `COMMIT` that fails after
  the last byte reaches only the server-side `onError` (`RlsCommitException`
  with `afterResponse: true`); the client already has its response.
- **Never capture the pool in a handler** to run an autocommit statement on
  tenant data: the tenant setting does not exist there. Treat it as a review rule.
- **The tenant comes from an authenticated source**, never from the body, the
  query or an unauthenticated header.
- **Routes without a tenant** (health, login) go in another `Pipeline`.
- **The database role** must be neither superuser, nor table owner, nor
  `BYPASSRLS`, and the table needs `FORCE ROW LEVEL SECURITY`; otherwise the
  policy does not apply.
- **`settingName`** (default `app.tenant_id`) must match the name the policy
  reads with `current_setting(..., true)`. It is configuration on purpose.

### Cost

Each request adds a `BEGIN`, the `set_config`, a `COMMIT` and the pool's
session reset on return. The cost of this middleware has not been measured.

### Tests

`test/rls_middleware_test.dart` and `test/prefix_ts_query_test.dart` need no
database. The integration tests (`test/integration/postgres_live_test.dart`,
`rls_live_test.dart` and `prefix_ts_query_live_test.dart`) need PostgreSQL at
`localhost:5432` (`dbname=teste user=postgres password=123`).
`prefix_ts_query_live_test.dart` creates no schema or role.
`rls_live_test.dart` uses a superuser because it creates schema `rls_mw` and
roles `rls_mw_owner`/`rls_mw_app`, so do not run two instances at once:

```bash
dart test
```

The integration tests **skip silently** without the library; confirm the skipped
count is zero.

### Stress suite (integrity under load)

`test/stress/` is tagged `stress` (`dart_test.yaml`). It asserts integrity invariants only and never emits time, throughput or latency: client and server share one event loop and the handlers sleep on purpose.

```bash
dart test -x stress                       # fast suite, skips the stress files
dart test -t stress -r compact
```

Parameters (environment): `STRESS_REQUESTS` (400), `STRESS_USERS` (32), `STRESS_SEED` (random, always printed; the same seed rebuilds the same intents). It uses its own schema and roles (`rls_stress*`), so it can run next to `rls_live_test.dart`.

It covers four pool configurations (1, 4, 2 without session reset, 2 with a 100 ms acquire timeout), four tenants with one hot tenant, client aborts at four moments, handlers that fail or answer 409, and a clean shutdown (`server.close()` then `pool.close()`) with requests in flight, plus a stream the client abandons before the first byte.

The suite SKIPS silently when the native library or Postgres is missing: check the printed `executed=N skipped=M` line (skipped must be 0).

## `prefixTsQuery`: prefix search from free text

Turns what a user types into a prefix `tsquery`, safe to bind as a parameter:

```dart
prefixTsQuery('jo sil');      // "'jo':* & 'sil':*"
prefixTsQuery("d'avila & !"); // "'d':* & 'avila':*"
prefixTsQuery('  &|! ');      // null
```

With a generated `tsvector` column and a GIN index:

```sql
CREATE TABLE person (
  id   serial PRIMARY KEY,
  name text NOT NULL,
  doc  tsvector GENERATED ALWAYS AS (to_tsvector('simple', name)) STORED
);
CREATE INDEX person_doc ON person USING gin (doc);
```

```dart
final q = prefixTsQuery(term);
if (q == null) return Response.badRequest(); // or run the query without the filter
final rows = await request.rls.executor.execute(
  "SELECT id, name FROM person WHERE doc @@ to_tsquery('simple', \$1)",
  params: [Param.text(q)],
);
```

Only runs of Unicode letters, combining marks and digits survive; every other
character (`& | ! ( ) : * < - >`, quotes, backslashes, spaces, punctuation) is
a separator. Each word becomes a quoted prefix lexeme, joined with `&`.

- **Normalise the input the way the index was built.** Case is folded by the
  text search configuration, but accents are kept: if the `tsvector` comes from
  `unaccent(...)`, apply the same removal to the term.
- **`null` means no word**: skip the filter. `to_tsquery` on an empty string
  matches nothing.
- **Always bind the result** (`Param.text`); never concatenate it into SQL.

### Cost

One regular expression pass over the input. Not measured.

## Example: CRUD server

`example/postgres_crud_server.dart` wires `BackendServer`, `Pipeline` and `Router` to the native pool. It
expects a `users` table:

```sql
CREATE TABLE users (id serial PRIMARY KEY, name text NOT NULL, email text NOT NULL UNIQUE);
```

```bash
POSTGRES_HOST=localhost POSTGRES_DB=teste POSTGRES_USER=postgres POSTGRES_PASSWORD=123 \
  dart run example/postgres_crud_server.dart
```

Endpoints: `GET /health`, `GET /api/v1/users` (first 50), `GET /api/v1/users/:id`, `POST /api/v1/users`
(inside a transaction). Error responses carry generic messages; exception details and PostgreSQL server
messages are logged on the server only. The server shuts down on `SIGINT` and `SIGTERM`.

`test/integration/postgres_live_test.dart` runs against the same database and skips when it, or the native
library, is unavailable.

## License

MIT, see `LICENSE`.
