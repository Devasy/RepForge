/// A wall-clock deadline avoids losing rest time when Flutter is paused.
class RestCountdown {
  RestCountdown(int seconds, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    deadline = _clock().add(Duration(seconds: seconds));
  }

  final DateTime Function() _clock;
  late DateTime deadline;

  int get remainingSeconds {
    final milliseconds = deadline.difference(_clock()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  void adjust(int seconds) {
    final next = (remainingSeconds + seconds).clamp(0, 600);
    deadline = _clock().add(Duration(seconds: next));
  }
}
