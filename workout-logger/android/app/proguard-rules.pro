# Suppress missing class warnings for Play Core deferred components in Flutter engine
-dontwarn com.google.android.play.core.**

# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# Keep Native plugins and Health Connect interfaces
-dontwarn com.google.android.gms.**

# R8 Optimizations for Google Play App Bundle
# Repackages obfuscated classes into a flat root package to minimize DEX string table overhead
-repackageclasses ''
# Widens access permissions to allow R8 to inline and devirtualize methods across package boundaries
-allowaccessmodification
