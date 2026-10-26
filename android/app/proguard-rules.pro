# R8 rules for release builds (isMinifyEnabled = true). Keep this file minimal: the kotlinx.serialization
# and OkHttp libraries ship their own consumer rules, so only app-specific needs belong here.

# Serializers are looked up by name through the generated `$serializer` and `Companion.serializer()`.
# The library rules cover @Serializable classes; these lines protect the metadata they read at runtime.
-keepattributes *Annotation*, InnerClasses, Signature
-dontnote kotlinx.serialization.**

# API models live in app.banh.customer.data and are decoded reflectively by name; keep their serializers.
-keepclassmembers class app.banh.customer.data.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class app.banh.customer.data.**$$serializer { *; }
