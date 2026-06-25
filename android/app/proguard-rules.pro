# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Keep annotated classes
-keep @androidx.annotation.Keep class * { *; }
-keepattributes Signature, InnerClasses, *Annotation*

# sqflite — native sqlite via JNI; keep all database-related classes
-keep class com.tekartik.sqflite.** { *; }

# flutter_local_notifications — receivers declared in manifest must survive shrinking
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# file_picker / SAF
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# device_info_plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Play Core (used by Flutter's deferred components)
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
