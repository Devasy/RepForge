import 'a2ui_props.dart';
import 'a2ui_spec.dart';

/// Normalized-name → spec lookup.
///
/// Replaces the old triple of `allowedA2UiComponents`, the validation `switch`
/// and the render `switch`: registering a spec adds it to all three at once.
class A2UiRegistry {
  A2UiRegistry(List<A2UiSpec> specs) : _specs = List.unmodifiable(specs) {
    for (final spec in _specs) {
      _byName[A2UiProps.normalizeKey(spec.name)] = spec;
      for (final alias in spec.aliases) {
        _byName.putIfAbsent(A2UiProps.normalizeKey(alias), () => spec);
      }
    }
  }

  final List<A2UiSpec> _specs;
  final Map<String, A2UiSpec> _byName = {};

  List<A2UiSpec> get specs => _specs;

  /// Looks up a spec by canonical name or any alias, ignoring case and
  /// separators (`stat_card`, `Stat Card` and `STATCARD` all match `StatCard`).
  A2UiSpec? specFor(String rawName) =>
      _byName[A2UiProps.normalizeKey(rawName)];

  String? canonicalName(String rawName) => specFor(rawName)?.name;
}
