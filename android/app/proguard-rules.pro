# Keep all TensorFlow Lite GPU classes
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep Flutter plugins
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.plugin.**

# Keep Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
