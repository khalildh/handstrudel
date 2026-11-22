# ---- MediaPipe (reflection + JNI) -------------------------------------------------
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.proto.**
# MediaPipe's TaskRunner logs through Flogger, which finds its caller by class name on the stack.
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**
# Task options/results are protobuf-lite messages read reflectively.
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
# AutoValue's processor ships inside a MediaPipe dependency; its javax.lang.model refs are compile-time only.
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**
-dontwarn com.google.auto.value.**
# Play review-ktx references a GMS annotation that isn't on the classpath.
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite

# ---- Rust core: UniFFI bindings over JNA (reflection on Structure fields, native callbacks) ----
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class uniffi.** { *; }
-dontwarn java.awt.**

# ---- WebView JS bridges -------------------------------------------------------------
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ---- kotlinx.serialization (app models, supabase-kt) --------------------------------
# The library ships rules for @Serializable classes; keep companions/serializers of our own
# models too in case they are looked up by reflection (serializer<T>() on generic types).
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
-keep,includedescriptorclasses class com.handstrudel.**$$serializer { *; }
-keepclassmembers class com.handstrudel.** {
    *** Companion;
}
-keepclasseswithmembers class com.handstrudel.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ---- Ktor / supabase-kt ---------------------------------------------------------------
-dontwarn org.slf4j.**
-dontwarn io.ktor.util.debug.**
-dontwarn java.lang.management.**
