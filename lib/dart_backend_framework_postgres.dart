/// PostgreSQL kit for `dart_backend_framework`.
///
/// For applications that use the framework together with
/// `dart_db_connector_postgres`. The framework has no database dependency;
/// this package holds the PostgreSQL-specific pieces for using the two together.
library;

export 'src/fts/prefix_ts_query.dart' show prefixTsQuery;

export 'src/rls/rls_exceptions.dart'
    show RlsCommitException, RlsContextException, RlsException;
export 'src/rls/rls_middleware.dart'
    show
        CommitPredicate,
        TenantResolver,
        commitOnSuccess,
        rlsTransaction,
        rlsTransactionOn;
export 'src/rls/rls_transaction.dart' show RlsRequest, RlsTransaction;
