/// Source of the current time. Injected so tests can control it.
abstract class Clock {
  /// Current instant, always UTC.
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
