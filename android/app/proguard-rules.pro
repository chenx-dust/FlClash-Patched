
-keep class com.follow.clash.models.** { *; }

-keep class com.follow.clash.service.models.** { *; }

# ML Kit discovers these component registrars at runtime. R8 full mode in
# Flutter 3.44 / AGP 9 can otherwise remove them from release builds.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.* { *; }
