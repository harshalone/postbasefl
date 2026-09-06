/// Immutable state threaded through the query builder chain, plus the
/// `/api/db/query` request-body builder. Not part of the public API.
library;

import '../types.dart';
import 'parsing.dart';

enum QueryOperation { select, insert, update, delete, upsert }

class NotFilter {
  const NotFilter(
      {required this.column, required this.operator, required this.value});

  final String column;
  final String operator;
  final Object? value;

  Map<String, Object?> toJson() =>
      {'column': column, 'operator': operator, 'value': value};
}

class RangeSpec {
  const RangeSpec({required this.from, required this.to});

  final int from;
  final int to;

  Map<String, Object?> toJson() => {'from': from, 'to': to};
}

class QueryState {
  const QueryState({
    required this.baseUrl,
    required this.apiKey,
    required this.table,
    this.columns = '*',
    this.selectCount,
    this.selectHead,
    this.filters = const [],
    this.orFilters = const [],
    this.notFilters = const [],
    this.orderBy = const [],
    this.joins = const [],
    this.limit,
    this.offset,
    this.range,
    this.operation = QueryOperation.select,
    this.insertData,
    this.upsertOnConflict,
    this.updateData,
    this.returning,
    this.extraHeaders = const {},
    this.cookieAdapter,
  });

  final String baseUrl;
  final String apiKey;
  final String table;
  final String columns;
  final String? selectCount;
  final bool? selectHead;
  final List<Filter> filters;
  final List<List<Filter>> orFilters;
  final List<NotFilter> notFilters;
  final List<OrderBy> orderBy;
  final List<JoinClause> joins;
  final int? limit;
  final int? offset;
  final RangeSpec? range;
  final QueryOperation operation;
  final Object?
      insertData; // Map<String, Object?> or List<Map<String, Object?>>
  final String? upsertOnConflict;
  final Map<String, Object?>? updateData;
  final String? returning;
  final Map<String, String> extraHeaders;
  final CookieAdapter? cookieAdapter;

  QueryState copyWith({
    String? columns,
    String? selectCount,
    bool? selectHead,
    List<Filter>? filters,
    List<List<Filter>>? orFilters,
    List<NotFilter>? notFilters,
    List<OrderBy>? orderBy,
    List<JoinClause>? joins,
    int? limit,
    bool clearLimit = false,
    int? offset,
    RangeSpec? range,
    QueryOperation? operation,
    Object? insertData,
    String? upsertOnConflict,
    Map<String, Object?>? updateData,
    String? returning,
  }) {
    return QueryState(
      baseUrl: baseUrl,
      apiKey: apiKey,
      table: table,
      columns: columns ?? this.columns,
      selectCount: selectCount ?? this.selectCount,
      selectHead: selectHead ?? this.selectHead,
      filters: filters ?? this.filters,
      orFilters: orFilters ?? this.orFilters,
      notFilters: notFilters ?? this.notFilters,
      orderBy: orderBy ?? this.orderBy,
      joins: joins ?? this.joins,
      limit: clearLimit ? null : (limit ?? this.limit),
      offset: offset ?? this.offset,
      range: range ?? this.range,
      operation: operation ?? this.operation,
      insertData: insertData ?? this.insertData,
      upsertOnConflict: upsertOnConflict ?? this.upsertOnConflict,
      updateData: updateData ?? this.updateData,
      returning: returning ?? this.returning,
      extraHeaders: extraHeaders,
      cookieAdapter: cookieAdapter,
    );
  }
}

/// Parsed columns are computed alongside the body so the caller can apply
/// aliases to the response without re-parsing.
class BuiltRequest {
  const BuiltRequest({required this.body, required this.parsedColumns});

  final Map<String, Object?> body;
  final List<ParsedColumn> parsedColumns;
}

BuiltRequest buildRequestBody(QueryState state) {
  final body = <String, Object?>{
    'operation': state.operation == QueryOperation.upsert
        ? 'upsert'
        : state.operation.name,
    'table': state.table,
  };

  var parsedColumns = const <ParsedColumn>[];
  if (state.operation == QueryOperation.select) {
    if (state.columns.isNotEmpty && state.columns != '*') {
      parsedColumns = parseColumns(state.columns);
      body['columns'] = parsedColumns.map((p) => p.col).toList();
    }
    if (state.selectCount != null) body['count'] = state.selectCount;
    if (state.selectHead != null) body['head'] = state.selectHead;
    if (state.joins.isNotEmpty) {
      body['joins'] = state.joins.map((j) => j.toJson()).toList();
    }
  }

  if (state.operation == QueryOperation.select ||
      state.operation == QueryOperation.update ||
      state.operation == QueryOperation.delete) {
    if (state.filters.isNotEmpty) {
      body['filters'] = state.filters.map((f) => f.toJson()).toList();
    }
    if (state.orFilters.isNotEmpty) {
      body['orFilters'] = state.orFilters
          .map((group) => group.map((f) => f.toJson()).toList())
          .toList();
    }
    if (state.notFilters.isNotEmpty) {
      body['notFilters'] = state.notFilters.map((f) => f.toJson()).toList();
    }
  }

  if (state.operation == QueryOperation.insert ||
      state.operation == QueryOperation.upsert) {
    body['data'] = state.insertData;
    if (state.upsertOnConflict != null) {
      body['onConflict'] = state.upsertOnConflict;
    }
  }

  if (state.operation == QueryOperation.update) {
    body['data'] = state.updateData;
  }

  if (state.orderBy.isNotEmpty) {
    body['order'] = state.orderBy.map((o) => o.toJson()).toList();
  }
  if (state.limit != null) body['limit'] = state.limit;
  if (state.offset != null) body['offset'] = state.offset;
  if (state.range != null) body['range'] = state.range!.toJson();
  if (state.returning != null) body['returning'] = state.returning;

  return BuiltRequest(body: body, parsedColumns: parsedColumns);
}
