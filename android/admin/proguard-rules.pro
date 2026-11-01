# R8 rules for release builds. The serialization and OkHttp libraries ship their own consumer rules.
-keepattributes *Annotation*, InnerClasses, Signature
-dontnote kotlinx.serialization.**

# Contract types are decoded by name through the generated serializers.
-keepclassmembers class app.banh.core.model.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class app.banh.core.model.**$$serializer { *; }
