/// Strategy used to compute delay for each retry attempt.
abstract interface class BackoffStrategy {
  /// Returns the delay for the 1-based [retryNumber], or `null` to stop retrying.
  Duration? delayForRetry(int retryNumber);
}

/// Fixed-delay retry strategy.
class FixedDelayBackoffStrategy implements BackoffStrategy {
  /// Creates a fixed-delay strategy.
  const FixedDelayBackoffStrategy({
    this.delays = const [
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
    this.repeatLastDelay = false,
  });

  /// Delay schedule indexed by retry number (1-based).
  final List<Duration> delays;

  /// Whether to repeat the final delay when retries exceed [delays] length.
  final bool repeatLastDelay;

  @override
  Duration? delayForRetry(int retryNumber) {
    if (retryNumber <= 0) {
      return null;
    }
    if (retryNumber <= delays.length) {
      return delays[retryNumber - 1];
    }
    if (repeatLastDelay && delays.isNotEmpty) {
      return delays.last;
    }
    return null;
  }
}

/// Delay function used by retry orchestration.
typedef DelayFn = Future<void> Function(Duration duration);
