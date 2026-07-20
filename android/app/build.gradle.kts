plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads MAPS_API_KEY out of env.json at build time, so it never needs
// to be a literal string in AndroidManifest.xml.
val envFile = rootProject.file("../env.json")
val mapsApiKey: String = if (envFile.exists()) {
    Regex("\"MAPS_API_KEY\"\\s*:\\s*\"([^\"]*)\"")
        .find(envFile.readText())
        ?.groupValues?.get(1) ?: ""
} else ""

android {
    namespace = "com.example.fmcg_salesman_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.fmcg_salesman_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}