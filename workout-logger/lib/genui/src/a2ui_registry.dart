import 'a2ui_props.dart';
import 'a2ui_spec.dart';

/// Normalized-name → spec lookup.
///
/// Replaces the old triple of `allowedA2UiComponents`, the validation `switch`
/// and the render `switch`: registering a spec adds it to all three at once.
class A2UiRegistry {
  A2UiRegistry(List<A2UiSpec> specs) : _specs = List.unmodifiable(specs) {
    for (final spec in _specs) {
      _register(A2UiProps.normalizeKey(spec.name), spec);
      for (final alias in spec.aliases) {
        _register(A2UiProps.normalizeKey(alias), spec);
      }
    }
  }

  /// Inserts [spec] under [key], throwing if [key] is already claimed —
  /// whether by a canonical name, an alias, or a repeat registration of the
  /// same spec class. Collisions are checked at insertion time in
  /// registration order so the error always names both the spec already
  /// registered and the one that collided with it, rather than silently
  /// overwriting or being silently dropped. (Const specs with identical
  /// fields canonicalize to `==` instances, so identity/equality checks
  /// can't be used to distinguish "same spec registered twice" from "two
  /// different specs that happen to collide" — every repeat claim of a key
  /// is treated as a collision.)
  void _register(String key, A2UiSpec spec) {
    final existing = _byName[key];
    if (existing != null) {
      throw StateError(
        'A2UiRegistry: "$key" is claimed by both '
        '${existing.name} and ${spec.name} (canonical name or alias '
        'collision). Component names and aliases must be unique across '
        'the registry.',
      );
    }
    _byName[key] = spec;
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
