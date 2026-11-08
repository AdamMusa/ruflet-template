import 'package:data_table_2/data_table_2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_datatable2/src/utils/datatable.dart';

void main() {
  test('column sizes match in any letter case', () {
    expect(parseColumnSize('s'), ColumnSize.S);
    expect(parseColumnSize('M'), ColumnSize.M);
    expect(parseColumnSize('l'), ColumnSize.L);
  });

  test('unknown or missing column sizes keep the default', () {
    expect(parseColumnSize('xl', ColumnSize.M), ColumnSize.M);
    expect(parseColumnSize(null, ColumnSize.S), ColumnSize.S);
  });
}
