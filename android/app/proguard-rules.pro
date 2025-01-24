# Flutter-specific rules
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Keep fields annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }

# Keep classes required for reflection
-keepnames class * { *; }

# Keep attributes needed for serialization/deserialization
-keepattributes Signature, InnerClasses

# Keep Play Core SplitCompatApplication
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.** { *; }

# Keep Flutter's PlayStore split application classes
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication