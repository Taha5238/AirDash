# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# WebRTC (if needed, though usually auto-kept)
-keep class org.webrtc.** { *; }

# Suppress Warnings (Common fix for initial R8 setup)
-dontwarn **
-keepattributes *Annotation*

