/// A Health Connect skin-temperature delta, with the bridge's baseline and
/// provenance preserved. A missing baseline must never be treated as zero.
class SkinTemperatureSample {
  const SkinTemperatureSample({
    required this.recordId,
    required this.recordStart,
    required this.recordEnd,
    required this.time,
    required this.deltaCelsius,
    required this.sourcePackage,
    required this.measurementLocation,
    this.baselineCelsius,
  });

  final String recordId;
  final DateTime recordStart;
  final DateTime recordEnd;
  final DateTime time;
  final double deltaCelsius;
  final double? baselineCelsius;
  final String sourcePackage;
  final String measurementLocation;
}
