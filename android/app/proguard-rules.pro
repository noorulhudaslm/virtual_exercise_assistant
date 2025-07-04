-keep class com.google.mediapipe.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class * {
    native <methods>;
}