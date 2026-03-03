abstract interface class BackoffStrategy {
  Duration? delayForRetry(int retryNumber);
}

class FixedDelayBackoffStrategy implements BackoffStrategy {
  const FixedDelayBackoffStrategy({
    this.delays = const [
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
  });

  final List<Duration> delays;

  @override
  Duration? delayForRetry(int retryNumber) {
    if (retryNumber <= 0 || retryNumber > delays.length) {
      return null;
    }
    return delays[retryNumber - 1];
  }
}

typedef DelayFn = Future<void> Function(Duration duration);
