import 'package:data_table_2/data_table_2.dart';
import 'package:ruflet/ruflet.dart';

/// Ruby sends the size names (`size: :medium`); Flet sends their initials.
const _columnSizeNames = {'small': 's', 'medium': 'm', 'large': 'l'};

ColumnSize? parseColumnSize(String? size, [ColumnSize? defValue]) {
  if (size == null) {
    return defValue;
  }
  final name = size.trim().toLowerCase();
  return parseEnum(ColumnSize.values, _columnSizeNames[name] ?? name, defValue);
}
