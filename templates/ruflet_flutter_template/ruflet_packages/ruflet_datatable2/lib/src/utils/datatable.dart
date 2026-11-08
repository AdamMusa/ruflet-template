import 'package:data_table_2/data_table_2.dart';
import 'package:ruflet/ruflet.dart';

ColumnSize? parseColumnSize(String? size, [ColumnSize? defValue]) {
  if (size == null) {
    return defValue;
  }
  return parseEnum(ColumnSize.values, size, defValue);
}
