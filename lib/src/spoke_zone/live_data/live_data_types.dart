part of '../live_data.dart';

/// Registration states for periodic live-data jobs.
enum LiveDataRegistrationState { idle, running, failed, canceled }

/// Snapshot of one periodic registration's current status.
class LiveDataRegistrationStatus {
  /// Creates an immutable registration status snapshot.
  const LiveDataRegistrationStatus({
    required this.state,
    required this.lastSuccessAt,
    required this.consecutiveFailures,
  });

  /// Current state for this registration.
  final LiveDataRegistrationState state;

  /// Timestamp of the latest successful publish, if any.
  final DateTime? lastSuccessAt;

  /// Count of consecutive failed publish attempts.
  final int consecutiveFailures;
}

/// Async provider used for periodic JSON payload generation.
typedef LiveDataPayloadProvider = Future<Map<String, dynamic>?> Function();
