/// Builds a PostgreSQL prefix `tsquery` from free text typed by a user.
///
/// Splits [input] into runs of Unicode letters, combining marks and digits;
/// everything else (spaces, punctuation, `& | ! ( ) : * < - >`, quotes,
/// backslashes) is a separator and never reaches the query. Each run becomes a
/// quoted prefix lexeme, and the lexemes are joined with ` & `:
///
/// ```dart
/// prefixTsQuery('jo sil');      // "'jo':* & 'sil':*"
/// prefixTsQuery("d'avila & !"); // "'d':* & 'avila':*"
/// prefixTsQuery('  &|! ');      // null
/// ```
///
/// Returns `null` when there is no word; `to_tsquery` on an empty string
/// matches nothing and raises a NOTICE, so skip the filter instead.
///
/// Case and accents are kept: the text search configuration folds case, and
/// the caller must apply to [input] the same normalisation (for example,
/// accent removal) used to build the indexed `tsvector`.
///
/// Pass the result as a bound text parameter, never concatenated into SQL:
///
/// ```dart
/// final q = prefixTsQuery(term);
/// if (q != null) {
///   await executor.execute(
///     "SELECT ... WHERE doc @@ to_tsquery('simple', \$1)",
///     params: [Param.text(q)],
///   );
/// }
/// ```
String? prefixTsQuery(String input) {
  final words = _word.allMatches(input).map((m) => m[0]!).toList();
  if (words.isEmpty) return null;
  return words.map((w) => '${quoteTsLexeme(w)}:*').join(' & ');
}

final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

/// Quotes [lexeme] for `tsquery` input: doubles single quotes and escapes
/// backslashes, then wraps it in single quotes. Not exported.
String quoteTsLexeme(String lexeme) =>
    "'${lexeme.replaceAll(r'\', r'\\').replaceAll("'", "''")}'";
