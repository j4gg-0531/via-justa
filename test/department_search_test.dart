import 'package:flutter_test/flutter_test.dart';
import 'package:via_justa/features/map_colombia/domain/department.dart';
import 'package:via_justa/features/map_colombia/domain/department_search.dart';

void main() {
  group('searchDepartments', () {
    test('empty query returns all departments', () {
      expect(searchDepartments(Departments.all, ''), Departments.all);
      expect(searchDepartments(Departments.all, '   '), Departments.all);
    });

    test('finds Cesar ignoring case', () {
      expect(searchDepartments(Departments.all, 'CESAR'), [Departments.cesar]);
    });

    test('finds La Guajira by partial name', () {
      expect(searchDepartments(Departments.all, 'guaj'), [
        Departments.laGuajira,
      ]);
    });

    test('returns an empty list when there are no matches', () {
      expect(searchDepartments(Departments.all, 'xyz'), isEmpty);
    });
  });
}
