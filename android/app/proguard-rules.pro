# Flutter engine and plugin system
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep generated plugin registrant
-keep class **.GeneratedPluginRegistrant { *; }

# Keep Pigeon generated APIs (critical for your error)
-keep class dev.flutter.pigeon.** { *; }

# Path Provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# Hive
-keep class hive.** { *; }
-keep class io.hive.** { *; }
-dontwarn hive.**
-dontwarn io.hive.**

# Kotlin metadata (prevents weird R8 issues sometimes)
-keep class dev.flutter.** { *; }

