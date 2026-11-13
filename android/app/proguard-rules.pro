-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# flutter_local_notifications saves every scheduled reminder with Gson and
# reads them back when the phone restarts (ScheduledNotificationBootReceiver).
# It ships no keep rules: R8 strips the generic signature Gson needs
# (TypeToken), so the saved list could not be read and reminders were lost
# after a reboot until the app was opened again.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
