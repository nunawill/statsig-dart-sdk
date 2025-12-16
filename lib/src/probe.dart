class StatsigProbe {
  final _records = <StatsigProbeRecord>[];

  List<StatsigProbeRecord> get records => _records;

  void add(String message) {
    _records.add(StatsigProbeRecord(DateTime.now(), message));
  }
}

class StatsigProbeRecord {
  const StatsigProbeRecord(this.timestamp, this.message);

  final DateTime timestamp;
  final String message;
}
