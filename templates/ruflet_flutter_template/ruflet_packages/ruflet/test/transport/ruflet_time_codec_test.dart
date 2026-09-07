import 'dart:convert';
import 'dart:typed_data';

import 'package:ruflet/src/models/ruflet_time.dart';
import 'package:ruflet/src/transport/ruflet_msgpack_decoder.dart';
import 'package:ruflet/src/transport/ruflet_msgpack_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('time-of-day wire values use a design-system-neutral model', () {
    final decoder = RufletMsgpackDecoder();
    final encoder = RufletMsgpackEncoder();
    final value = decoder.decodeObject(
        2, Uint8List.fromList(utf8.encode('14:35'))) as RufletTime;

    expect(value, const RufletTime(hour: 14, minute: 35));
    expect(encoder.extTypeForObject(value), 2);
    expect(utf8.decode(encoder.encodeObject(value)), '14:35');
  });
}
