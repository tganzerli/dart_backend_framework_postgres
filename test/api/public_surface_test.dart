/// Smoke test for the public API surface.
///
/// Imports ONLY the package barrel, NOT any `src/` path. The test is
/// compile-only — no DB is needed. If any symbol disappears from the barrel,
/// this file fails to compile. `quoteTsLexeme` is not part of the surface.
library;

// ignore_for_file: unused_local_variable

import 'package:dart_backend_framework/dart_backend_framework.dart';
import 'package:dart_backend_framework_postgres/dart_backend_framework_postgres.dart';
import 'package:test/test.dart';

void main() {
  test('barrel exposes the RLS middleware and prefixTsQuery', () {
    // Types (6)
    expect(RlsException, isA<Type>());
    expect(RlsContextException, isA<Type>());
    expect(RlsCommitException, isA<Type>());
    expect(RlsTransaction, isA<Type>());
    expect(CommitPredicate, isA<Type>());
    expect(TenantResolver, isA<Type>());

    // Functions (4)
    expect(rlsTransaction, isA<Function>());
    expect(rlsTransactionOn, isA<Function>());
    expect(commitOnSuccess, isA<Function>());
    expect(prefixTsQuery, isA<Function>());

    // Extension `RlsRequest`, referenced by use in a body that never runs.
    RlsTransaction rlsOf(Request request) => request.rls;
    expect(rlsOf, isA<Function>());
  });
}
