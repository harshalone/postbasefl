import 'package:postbase/postbase.dart';
import 'package:postbase/src/internal/parsing.dart';
import 'package:test/test.dart';

void main() {
  group('parseColumns', () {
    test('no alias', () {
      final parsed = parseColumns('id, title, created_at');
      expect(parsed.map((p) => p.col).toList(), ['id', 'title', 'created_at']);
      expect(
          parsed.map((p) => p.alias).toList(), ['id', 'title', 'created_at']);
    });

    test('with alias', () {
      final parsed = parseColumns(
          'apis.id as api_id, apis.name, pricing_plans.id as plan_id');
      expect(parsed[0].col, 'apis.id');
      expect(parsed[0].alias, 'api_id');
      expect(parsed[1].col, 'apis.name');
      expect(parsed[1].alias, 'apis.name');
      expect(parsed[2].col, 'pricing_plans.id');
      expect(parsed[2].alias, 'plan_id');
    });

    test('AS is case-insensitive', () {
      final parsed = parseColumns('apis.id AS api_id');
      expect(parsed[0].col, 'apis.id');
      expect(parsed[0].alias, 'api_id');
    });
  });

  group('applyAliases', () {
    test('renames keys using server-response shape', () {
      final parsed = parseColumns(
          'apis.id as api_id, apis.name, pricing_plans.id as plan_id');
      final rows = [
        {'id': '1', 'name': 'Foo', 'plan_id': '2'},
      ];
      final out = applyAliases(rows, parsed);
      expect(out, [
        {'api_id': '1', 'name': 'Foo', 'plan_id': '2'},
      ]);
    });

    test('noop without alias', () {
      final parsed = parseColumns('id, name');
      final rows = [
        {'id': '1', 'name': 'Foo'},
      ];
      expect(applyAliases(rows, parsed), rows);
    });
  });

  group('parseOrFilterString', () {
    test('simple OR', () {
      final filters =
          parseOrFilterString('email.ilike.%alice%,name.ilike.%alice%');
      expect(filters, hasLength(2));
      expect(filters[0].column, 'email');
      expect(filters[0].operator, FilterOperator.ilike);
      expect(filters[0].value, '%alice%');
      expect(filters[1].column, 'name');
    });

    test('in operator inside OR', () {
      final filters =
          parseOrFilterString('status.eq.active,status.in.(pending,review)');
      expect(filters[0].value, 'active');
      expect(filters[1].operator, FilterOperator.in_);
      expect(filters[1].value, ['pending', 'review']);
    });

    test('booleans and null', () {
      final filters = parseOrFilterString(
          'published.eq.true,archived.eq.false,deleted_at.eq.null');
      expect(filters[0].value, true);
      expect(filters[1].value, false);
      expect(filters[2].value, null);
    });

    test('commas inside parens are not split', () {
      final filters = parseOrFilterString('role.in.(admin,owner,editor)');
      expect(filters, hasLength(1));
      expect(filters[0].operator, FilterOperator.in_);
      expect(filters[0].value, ['admin', 'owner', 'editor']);
    });
  });
}
