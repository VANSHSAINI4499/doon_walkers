pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 8.9.1 minimum — required by mobile_scanner's camera dependencies
    // (androidx.camera:camera-* 1.6.1), which also require compileSdk 36.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
    // Phase 8 (FCM push notifications) — reads android/app/google-services.json
    // and generates the resources firebase_core needs at build time.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
