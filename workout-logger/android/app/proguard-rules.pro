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
