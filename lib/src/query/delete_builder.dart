/// Builder returned by `.delete()`.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

import '../internal/query_state.dart';
import '../types.dart';
import 'execute.dart';
import 'filter_mixin.dart';

class DeleteBuilder<T>
    with FilterMixin<DeleteBuilder<T>>
    implements Future<QueryResult<T>> {
  DeleteBuilder(this._client, this.state, this._map);

  final http.Client _client;
  @override
  final QueryState state;
  final T Function(Map<String, Object?>) _map;

  @override
  DeleteBuilder<T> withState(QueryState state) =>
      DeleteBuilder<T>(_client, state, _map);

  /// Choose which columns to return after the delete.
  DeleteBuilder<T> select([String columns = '*']) =>
      withState(state.copyWith(returning: columns));

  /// Execute and return a single row.
  Future<SingleResult<T>> single() async {
    final result = await executeQuery(_client, state);
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
