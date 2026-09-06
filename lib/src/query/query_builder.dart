/// The main chainable query builder returned by `client.from(table)`.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

import '../internal/query_state.dart';
import '../types.dart';
import 'delete_builder.dart';
import 'execute.dart';
import 'filter_mixin.dart';
import 'insert_builder.dart';
import 'update_builder.dart';

/// Chainable, immutable query builder for a single table. Every method
/// returns a new builder — nothing is sent until you `await` it directly or
/// call [single] / [maybeSingle].
class QueryBuilder<T>
    with FilterMixin<QueryBuilder<T>>
    implements Future<QueryResult<T>> {
  QueryBuilder(this._client, this.state, this._map);

  final http.Client _client;
  @override
  final QueryState state;
  final T Function(Map<String, Object?>) _map;

  @override
  QueryBuilder<T> withState(QueryState state) =>
      QueryBuilder<T>(_client, state, _map);

  /// Select columns. Omit or pass `'*'` for all columns.
  QueryBuilder<T> select(
      [String columns = '*', SelectOptions options = const SelectOptions()]) {
    return withState(state.copyWith(
      columns: columns,
      selectCount: options.count,
      selectHead: options.head,
      operation: QueryOperation.select,
    ));
  }

  /// Join another table.
  QueryBuilder<T> join(String table, {required String on, JoinType? type}) {
    return withState(state.copyWith(
        joins: [...state.joins, JoinClause(table: table, on: on, type: type)]));
  }

  /// Order results by [column].
  QueryBuilder<T> order(String column, {bool? ascending, bool? nullsFirst}) {
    return withState(state.copyWith(
      orderBy: [
        ...state.orderBy,
        OrderBy(column: column, ascending: ascending, nullsFirst: nullsFirst)
      ],
    ));
  }

  /// Limit the number of rows returned.
  QueryBuilder<T> limit(int count) => withState(state.copyWith(limit: count));

  /// Skip the first [count] rows.
  QueryBuilder<T> offset(int count) => withState(state.copyWith(offset: count));

  /// Return an inclusive range of rows `[from, to]`.
  QueryBuilder<T> range(int from, int to) {
    return withState(state.copyWith(
        range: RangeSpec(from: from, to: to),
        limit: to - from + 1,
        offset: from));
  }

  /// Insert one or more rows.
  InsertBuilder<T> insert(Object data, {String returning = '*'}) {
    return InsertBuilder<T>(
      _client,
      state.copyWith(
          operation: QueryOperation.insert,
          insertData: data,
          returning: returning),
      _map,
    );
  }

  /// Insert or update on conflict.
  InsertBuilder<T> upsert(Object data,
      {String? onConflict, String returning = '*'}) {
    return InsertBuilder<T>(
      _client,
      state.copyWith(
        operation: QueryOperation.upsert,
        insertData: data,
        upsertOnConflict: onConflict,
        returning: returning,
      ),
      _map,
    );
  }

  /// Update matching rows.
  UpdateBuilder<T> update(Map<String, Object?> data) {
    return UpdateBuilder<T>(
      _client,
      state.copyWith(
          operation: QueryOperation.update, updateData: data, returning: '*'),
      _map,
    );
  }

  /// Delete matching rows.
  DeleteBuilder<T> delete() {
    return DeleteBuilder<T>(_client,
        state.copyWith(operation: QueryOperation.delete, returning: '*'), _map);
  }

  /// Execute and return a single row — errors if the result isn't exactly one row.
  Future<SingleResult<T>> single() async {
    final result = await executeQuery(_client, state.copyWith(limit: 1));
    if (result.error != null) {
      return SingleResult(data: null, error: result.error);
    }
    final rows = result.data ?? const [];
    if (rows.isEmpty) {
      return const SingleResult(data: null, error: 'No rows returned');
    }
    if (rows.length > 1) {
      return const SingleResult(data: null, error: 'Multiple rows returned');
    }
    return SingleResult(data: _map(rows.first), error: null);
  }

  /// Execute and return a single row, or `null` if not found (no error).
  Future<SingleResult<T>> maybeSingle() async {
    final result = await executeQuery(_client, state.copyWith(limit: 1));
    if (result.error != null) {
      return SingleResult(data: null, error: result.error);
    }
    final rows = result.data ?? const [];
    return SingleResult(
        data: rows.isEmpty ? null : _map(rows.first), error: null);
  }

  Future<QueryResult<T>> _execute() async {
    final result = await executeQuery(_client, state);
    if (result.error != null) {
      return QueryResult(data: null, count: result.count, error: result.error);
    }
    final rows = result.data ?? const [];
    return QueryResult(
        data: rows.map(_map).toList(), count: result.count, error: null);
  }

  // ─── Future<QueryResult<T>> passthrough (makes the builder awaitable) ──────

  @override
  Stream<QueryResult<T>> asStream() => _execute().asStream();

  @override
  Future<QueryResult<T>> catchError(Function onError,
          {bool Function(Object)? test}) =>
      _execute().catchError(onError, test: test);

  @override
  Future<R> then<R>(FutureOr<R> Function(QueryResult<T> value) onValue,
          {Function? onError}) =>
      _execute().then(onValue, onError: onError);

  @override
  Future<QueryResult<T>> timeout(Duration timeLimit,
          {FutureOr<QueryResult<T>> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<QueryResult<T>> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);
}

/// Options accepted by [QueryBuilder.select].
class SelectOptions {
  const SelectOptions({this.count, this.head});

  /// `exact`, `planned`, or `estimated`.
  final String? count;
  final bool? head;
}
