# --- Flutter engine & embedding ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Native method bindings & annotations ---
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepclasseswithmembernames class * { native <methods>; }

# --- local_auth (AndroidX Biometric) ---
-keep class androidx.biometric.** { *; }

# --- flutter_secure_storage (Android Keystore) ---
-keep class androidx.security.crypto.** { *; }

# --- Kotlin metadata (safe default) ---
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
