import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/skin_temperature_sample.dart';
import 'package:repforge/services/health_metrics_service.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'test_utils/stub_health_connect_service.dart';

class MetricHc extends StubHcService implements IHealthMetricPermissions {
  bool available = true;
  Set<HealthReadType> granted = {};
  List<HealthSample> hrv = [];
  List<SkinTemperatureSample> temperature = [];
  final requested = <HealthReadType>[];
  int reads = 0;
  bool fail = false;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<Set<HealthReadType>> grantedReadTypes() async => granted;
  @override
  Future<bool> requestMetricReadPermission(HealthReadType type) async {
    requested.add(type);
    granted.add(type);
    return true;
  }
  @override
  Future<List<HealthSample>> readHrvRmssd(DateTime start, DateTime end) async {
    reads++;
    if (fail) throw StateError('failed page');
    return hrv;
  }
  @override
  Future<List<SkinTemperatureSample>> readSkinTemperature(DateTime start, DateTime end) async {
    reads++;
    if (fail) throw StateError('failed page');
    return temperature;
  }
}

void main() {
  final now = DateTime(2026, 11, 14, 12);
  late MetricHc hc;
  late HealthMetricsService service;
  setUp(() {
    hc = MetricHc();
    service = HealthMetricsService(hc, now: () => now);
  });
  test('unavailable and denied access do not read data', () async {
    hc.available = false;
    expect((await service.load(HealthMetric.hrv)).access, HealthMetricAccess.unavailable);
    hc.available = true;
    expect((await service.load(HealthMetric.hrv)).access, HealthMetricAccess.permissionRequired);
    expect(hc.reads, 0);
  });
  test('connect requests only the selected metric', () async {
    await service.connect(HealthMetric.skinTemperature);
    expect(hc.requested, [HealthReadType.skinTemperature]);
    expect(hc.granted, {HealthReadType.skinTemperature});
  });
  test('HRV daily averages retain gaps, exclude future and invalid samples', () async {
    hc.granted = {HealthReadType.hrv};
    hc.hrv = [
      HealthSample(time: DateTime(2026, 11, 8), value: 40),
      HealthSample(time: DateTime(2026, 11, 8, 10), value: 60),
      HealthSample(time: DateTime(2026, 11, 10), value: 70),
      HealthSample(time: DateTime(2026, 11, 7, 23, 59), value: 99),
      HealthSample(time: now.add(const Duration(seconds: 1)), value: 99),
      HealthSample(time: now, value: double.nan),
      HealthSample(time: now, value: -1),
    ];
    final result = await service.load(HealthMetric.hrv);
    expect(result.start, DateTime(2026, 11, 8));
    expect(result.series.single.unit, 'ms');
    expect(result.series.single.points.map((p) => p.value), [50, 70]);
    expect(result.series.single.points.map((p) => p.day.day), [8, 10]);
  });
  SkinTemperatureSample sample(String id, String source, String location, double delta, {double? baseline}) => SkinTemperatureSample(
    recordId: id, recordStart: now.subtract(const Duration(hours: 8)), recordEnd: now,
    time: now.subtract(const Duration(hours: 2)), deltaCelsius: delta,
    baselineCelsius: baseline, sourcePackage: source, measurementLocation: location,
  );
  test('temperature keeps sources, sites and unknown baselines separate', () async {
    hc.granted = {HealthReadType.skinTemperature};
    final a = sample('a', 'source.a', 'wrist', .5, baseline: 33);
    hc.temperature = [a, a,
      sample('b', 'source.a', 'wrist', -.5, baseline: 35),
      sample('c', 'source.b', 'wrist', .4, baseline: 34),
      sample('d', 'source.a', 'finger', .1, baseline: 32),
      sample('e', 'source.a', 'wrist', .3),
      sample('f', 'source.a', 'wrist', -.2),
    ];
    final result = await service.load(HealthMetric.skinTemperature);
    expect(result.series, hasLength(5));
    final absolute = result.series.singleWhere((s) => s.source == 'source.a' && s.location == 'wrist' && !s.isDelta);
    expect(absolute.points.single.value, 34);
    expect(result.series.where((s) => s.isDelta).map((s) => s.points.single.value), containsAll([.3, -.2]));
  });
  test('empty and failed reads remain distinguishable', () async {
    hc.granted = {HealthReadType.hrv};
    expect((await service.load(HealthMetric.hrv)).series, isEmpty);
    hc.fail = true;
    await expectLater(service.load(HealthMetric.hrv), throwsStateError);
  });
}
