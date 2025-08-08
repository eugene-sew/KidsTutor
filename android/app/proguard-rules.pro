# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# TensorFlow Lite rules
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }

# Keep the GPU delegate classes and their options, including nested classes.
-keep public class org.tensorflow.lite.gpu.** {
    public *;
}
-dontwarn org.tensorflow.lite.gpu.**

# Google Play Core library rules for Flutter deferred components
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }

# General Play Core rules
-keep public class com.google.android.play.core.** { public *; }
-keep public interface com.google.android.play.core.** { public *; }
