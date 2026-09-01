/// Design-system-neutral time-of-day value used by the wire protocol.
class FletTime {
  final int hour;
  final int minute;

  const FletTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  factory FletTime.now() {
    final now = DateTime.now();
    return FletTime(hour: now.hour, minute: now.minute);
  }

  @override
  bool operator ==(Object other) =>
      other is FletTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
