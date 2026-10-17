import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (upload key for Google Play) comes from android/key.properties, which is
// gitignored. Without it, release builds fall back to the debug key (fine for local testing,
// rejected by Google Play). See docs/RUNBOOK.md.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.universalstockadvisor.stock_adviser"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.universalstockadvisor.stock_adviser"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Plain http:// is only for talking to a dev server on the LAN. Debug/profile builds
        // allow it; release builds only with `-P allowCleartext=true` (never for Google Play).
        manifestPlaceholders["usesCleartextTraffic"] =
            (project.findProperty("allowCleartext") ?: "false").toString()
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        getByName("profile") {
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            signingConfig =
                if (hasUploadKey) signingConfigs.getByName("upload")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
