part of '../live_data.dart';

/// Minimal periodic timer contract used for scheduler injection.
abstract interface class PeriodicTimer {
  /// Cancels future ticks.
  void cancel();
}

/// Factory for creating periodic timers.
typedef PeriodicTimerFactory =
    PeriodicTimer Function(Duration interval, void Function() onTick);

class _SystemPeriodicTimer implements PeriodicTimer {
  _SystemPeriodicTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

PeriodicTimer _systemPeriodicTimerFactory(
  Duration interval,
  void Function() onTick,
) {
  return _SystemPeriodicTimer(Timer.periodic(interval, (_) => onTick()));
}
