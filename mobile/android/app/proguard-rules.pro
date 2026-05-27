# ML Kit Barcode Scanning — keep all model and scanner classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# CameraX — used by mobile_scanner
-keep class androidx.camera.** { *; }

# mobile_scanner plugin internals
-keep class dev.steenbakker.mobile_scanner.** { *; }
