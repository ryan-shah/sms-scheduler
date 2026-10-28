import 'package:sms_scheduler/domain/clock.dart';

class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  set time(DateTime t) => _now = t.toUtc();

  void advance(Duration d) => _now = _now.add(d);
}
