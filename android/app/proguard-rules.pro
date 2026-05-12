# Keep MediaPipe classes
-keep class com.google.mediapipe.** { *; }

# Keep WebView JS interface
-keepclassmembers class com.handstrudel.engine.StrudelBridge$JsBridge {
    public *;
}
