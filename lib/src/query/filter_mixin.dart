/// Shared filter/order chaining methods for query builders.
library;

import '../internal/parsing.dart';
import '../internal/query_state.dart';
import '../types.dart';

/// Mixin providing the filter chain (`.eq`, `.neq`, `.or`, `.not`, ...)
/// shared by [QueryBuilder], [UpdateBuilder], and [DeleteBuilder].
///
/// [B] is the concrete builder type so chained calls return the right class.
mixin FilterMixin<B> {
  QueryState get state;

  B withState(QueryState state);

  B _addFilter(String column, FilterOperator operator, Object? value) {
    return withState(state.copyWith(filters: [
      ...state.filters,
      Filter(column: column, operator: operator, value: value)
    ]));
  }

  /// Filter: `column = value`.
  B eq(String column, Object? value) =>
      _addFilter(column, FilterOperator.eq, value);

  /// Filter: `column != value`.
  B neq(String column, Object? value) =>
      _addFilter(column, FilterOperator.neq, value);

  /// Filter: `column > value`.
  B gt(String column, Object? value) =>
      _addFilter(column, FilterOperator.gt, value);

  /// Filter: `column >= value`.
  B gte(String column, Object? value) =>
      _addFilter(column, FilterOperator.gte, value);

  /// Filter: `column < value`.
  B lt(String column, Object? value) =>
      _addFilter(column, FilterOperator.lt, value);

  /// Filter: `column <= value`.
  B lte(String column, Object? value) =>
      _addFilter(column, FilterOperator.lte, value);

  /// Filter: `column LIKE pattern`.
  B like(String column, String pattern) =>
      _addFilter(column, FilterOperator.like, pattern);

  /// Filter: `column ILIKE pattern` (case-insensitive).
  B ilike(String column, String pattern) =>
      _addFilter(column, FilterOperator.ilike, pattern);

  /// Filter: `column IN (values)`.
  B in_(String column, List<Object?> values) =>
      _addFilter(column, FilterOperator.in_, values);

  /// Filter: `column IS NULL` / `IS TRUE` / `IS FALSE`.
  B is_(String column, Object? value) =>
      _addFilter(column, FilterOperator.is_, value);

  /// Filter: `column @> value` (array/jsonb contains).
  B contains(String column, Object? value) =>
      _addFilter(column, FilterOperator.contains, value);

  /// Filter: `column && value` (array overlaps).
  B overlaps(String column, List<Object?> value) =>
      _addFilter(column, FilterOperator.overlaps, value);

  /// Full-text search on `column`.
  B textSearch(String column, String query, {String? config}) {
    return _addFilter(
        column, FilterOperator.textSearch, {'query': query, 'config': config});
  }

  /// Combine filters with OR, using a Supabase-compatible filter string, e.g.
  /// `"email.ilike.%foo%,name.ilike.%foo%"`.
  B or(String filters) {
    return withState(state.copyWith(
        orFilters: [...state.orFilters, parseOrFilterString(filters)]));
  }

  /// Negate a filter: `NOT column operator value`.
  B not(String column, String operator, Object? value) {
    return withState(
      state.copyWith(notFilters: [
        ...state.notFilters,
        NotFilter(column: column, operator: operator, value: value)
      ]),
    );
  }
}
