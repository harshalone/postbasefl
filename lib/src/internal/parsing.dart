/// Internal helpers shared by the query builder: column/alias parsing and the
/// Supabase-compatible OR-filter string parser. Not part of the public API.
library;

import '../types.dart';

// ─── Column parsing (SELECT "col AS alias" support) ────────────────────────

class ParsedColumn {
  const ParsedColumn({required this.col, required this.alias});

  /// Bare identifier or `table.column` sent to the server.
  final String col;

  /// Key used in the returned row object.
  final String alias;
}

final RegExp _asPattern = RegExp(r'\s+[Aa][Ss]\s+');

List<ParsedColumn> parseColumns(String columns) {
  return columns.split(',').map((raw) {
    final part = raw.trim();
    final match = _asPattern.firstMatch(part);
    if (match == null) {
      return ParsedColumn(col: part, alias: part);
    }
    final col = part.substring(0, match.start).trim();
    final alias = part.substring(match.end).trim();
    return ParsedColumn(col: col, alias: alias);
  }).toList();
}

List<Map<String, Object?>> applyAliases(
  List<Map<String, Object?>> rows,
  List<ParsedColumn> parsed,
) {
  // Build serverKey -> alias map. When two qualified columns share the same
  // bare name (e.g. apis.id and pricing_plans.id both resolve to "id"), the
  // server already collapsed them to one key before we see the response, so
  // only one alias can be applied. Process in declaration order so the first
  // alias wins, matching the most common intent.
  final aliasMap = <String, String>{};
  for (final p in parsed) {
    if (p.col != p.alias) {
      final serverKey = p.col.contains('.') ? p.col.split('.').last : p.col;
      aliasMap.putIfAbsent(serverKey, () => p.alias);
    }
  }
  if (aliasMap.isEmpty) return rows;
  return rows.map((row) {
    final out = <String, Object?>{};
    row.forEach((k, v) {
      out[aliasMap[k] ?? k] = v;
    });
    return out;
  }).toList();
}

// ─── OR filter string parser ────────────────────────────────────────────────
//
// Parses Supabase/postbasejs-style filter strings into structured Filter
// lists.
//   "email.ilike.%foo%,name.ilike.%foo%"  -> [Filter, Filter]
//   "status.eq.active,age.gt.18"          -> [Filter, Filter]
//   "role.in.(admin,owner)"               -> [Filter(op: in_, value: [...])]
//
// The value is everything after the second dot, so dots in values are safe.
// Commas inside balanced parentheses (for the `in` operator) are not split on.

List<Filter> parseOrFilterString(String filterStr) {
  final segments = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < filterStr.length; i++) {
    final ch = filterStr[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    } else if (ch == ',' && depth == 0) {
      segments.add(filterStr.substring(start, i).trim());
      start = i + 1;
    }
  }
  segments.add(filterStr.substring(start).trim());

  return segments.where((s) => s.isNotEmpty).map((seg) {
    final firstDot = seg.indexOf('.');
    final secondDot = firstDot == -1 ? -1 : seg.indexOf('.', firstDot + 1);
    if (firstDot == -1 || secondDot == -1) {
      // Malformed segment — pass through as-is with eq operator.
      return Filter(column: seg, operator: FilterOperator.eq, value: null);
    }
    final column = seg.substring(0, firstDot);
    final operatorStr = seg.substring(firstDot + 1, secondDot);
    final rawValue = seg.substring(secondDot + 1);
    final operator = _operatorFromWire(operatorStr);

    Object? value = rawValue;
    if (operator == FilterOperator.in_) {
      var inner = rawValue;
      if (inner.startsWith('(')) inner = inner.substring(1);
      if (inner.endsWith(')')) inner = inner.substring(0, inner.length - 1);
      value = inner.split(',').map((v) => v.trim()).toList();
    } else if (rawValue == 'true') {
      value = true;
    } else if (rawValue == 'false') {
      value = false;
    } else if (rawValue == 'null') {
      value = null;
    }

    return Filter(column: column, operator: operator, value: value);
  }).toList();
}

FilterOperator _operatorFromWire(String wire) {
  switch (wire) {
    case 'in':
      return FilterOperator.in_;
    case 'is':
      return FilterOperator.is_;
    case 'textSearch':
      return FilterOperator.textSearch;
  }
  return FilterOperator.values.firstWhere(
    (o) => o.name == wire,
    orElse: () => FilterOperator.eq,
  );
}
