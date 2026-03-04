part of '../live_data.dart';

/// Handle returned by periodic registration APIs.
class LiveDataRegistration {
  LiveDataRegistration._(this._cancel, this._statusNotifier);

  final Future<void> Function() _cancel;
  final ValueNotifier<LiveDataRegistrationStatus> _statusNotifier;

  /// Current registration status snapshot.
  LiveDataRegistrationStatus get status => _statusNotifier.value;

  /// Observable status updates for this registration.
  ValueListenable<LiveDataRegistrationStatus> get statusListenable =>
      _statusNotifier;

  /// Cancels this registration.
  Future<void> cancel() => _cancel();
}

class _RegistrationRecord {
  _RegistrationRecord({
    required this.topic,
    required this.payloadProvider,
    required this.interval,
    required this.retained,
    required this.statusNotifier,
  });

  final String topic;
  final LiveDataPayloadProvider payloadProvider;
  final Duration interval;
  final bool retained;
  final ValueNotifier<LiveDataRegistrationStatus> statusNotifier;

  bool canceled = false;
  bool isPublishing = false;
  PeriodicTimer? timer;
}
