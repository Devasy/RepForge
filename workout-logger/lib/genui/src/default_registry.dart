import 'a2ui_registry.dart';
import 'components/data_list_group.dart';
import 'components/dynamic_chart.dart';
import 'components/filter_chips.dart';
import 'components/grid_container.dart';
import 'components/metric_gauge.dart';
import 'components/radar_chart.dart';
import 'components/scatter_plot.dart';
import 'components/stat_card.dart';

/// The standard A2UI vocabulary.
///
/// Registration order is the order components appear in the generated prompt,
/// so the most commonly useful ones come first. Adding a component here adds it
/// to the parser, the renderer and the model's instructions at once.
final A2UiRegistry defaultA2UiRegistry = A2UiRegistry(const [
  GridContainerSpec(),
  StatCardSpec(),
  DynamicChartSpec(),
  DataListGroupSpec(),
  MetricGaugeSpec(),
  ScatterPlotSpec(),
  RadarChartSpec(),
  FilterChipsSpec(),
]);
