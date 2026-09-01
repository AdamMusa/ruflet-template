import 'dart:convert';
import 'dart:typed_data';

import 'package:flet/src/models/flet_time.dart';
import 'package:flet/src/transport/flet_msgpack_decoder.dart';
import 'package:flet/src/transport/flet_msgpack_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('time-of-day wire values use a design-system-neutral model', () {
    final decoder = FletMsgpackDecoder();
    final encoder = FletMsgpackEncoder();
    final value = decoder.decodeObject(
        2, Uint8List.fromList(utf8.encode('14:35'))) as FletTime;

    expect(value, const FletTime(hour: 14, minute: 35));
    expect(encoder.extTypeForObject(value), 2);
    expect(utf8.decode(encoder.encodeObject(value)), '14:35');
  });
}
