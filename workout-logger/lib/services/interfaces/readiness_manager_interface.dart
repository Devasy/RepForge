// Readiness Manager Interface (Dependency Inversion Principle)
//
// Abstracts daily readiness computation from Health Connect sleep/heart data.
// UI widgets depend on this abstraction so the data source and scoring can be
// swapped or mocked in tests.

import '../../models/models.dart';

enum ReadinessStatus { idle, loading, ready, noData }

/// Contract for computing and caching the user's daily readiness score.
abstract class IReadinessManager {
  ReadinessStatus get status;

  /// Today's readiness, or null when nothing has been computed yet.
  ReadinessSnapshot? get snapshot;

  /// Recomputes today's readiness from Health Connect.
  ///
  /// - No-op when the readiness setting is disabled.
  /// - Serves a same-day cached snapshot (within a freshness TTL) unless
  ///   [force] is true.
  /// - Never throws: any failure results in [ReadinessStatus.noData].
  Future<void> refresh({bool force = false});
}
