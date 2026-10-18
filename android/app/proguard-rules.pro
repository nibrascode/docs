-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
# Keep Stripe classes
-keep class com.stripe.** { *; }
# Flutter plugins (Pigeon-generated APIs are invoked reflectively / via JNI-like channels)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class net.nfet.flutter.printing.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class io.github.ponnamkarthik.toast.fluttertoast.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
# Kotlin coroutines / metadata used by Pigeon suspend APIs
-keep class kotlinx.coroutines.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions
-dontwarn kotlinx.coroutines.**
-dontwarn com.google.android.play.core.**
