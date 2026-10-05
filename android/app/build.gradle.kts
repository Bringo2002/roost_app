import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local, gitignored secrets (Maps API key etc). Add a line like
// MAPS_API_KEY=your_key_here to android/local.properties -- never commit
// the actual key.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

// Release signing config. Copy android/key.properties.example to
// android/key.properties (gitignored) and fill it in. The keystore itself
// must never be committed either.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)
        ?: error("android/key.properties is missing required property '$name'")

android {
    namespace = "com.roost.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.roost.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        ndk {
            // Works around a known Flutter/Gradle tooling bug where release
            // builds fail with "failed to strip debug symbols from native
            // libraries" (open upstream as of Flutter 3.44). Skipping symbol
            // table generation avoids the broken stripping step entirely.
            debugSymbolLevel = "NONE"
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
                storeFile = file(requiredKeystoreProperty("storeFile"))
                storePassword = requiredKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties, fall back to the debug key so local
            // `flutter run --release` and sideloaded APKs keep working. The
            // taskGraph guard below stops that fallback from ever producing a
            // Play Store bundle.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    if (hasReleaseKeystore) return@whenReady
    // Match the exact task name: "bundleRelease" is a substring of tasks such
    // as bundleReleaseResources that also run during a plain APK build.
    if (allTasks.any { it.name == "bundleRelease" }) {
        throw GradleException(
            "Refusing to build a release app bundle signed with the debug key. " +
                "Create android/key.properties (see key.properties.example).",
        )
    }
    if (allTasks.any { it.name == "assembleRelease" }) {
        logger.warn(
            "WARNING: android/key.properties not found; the release APK is " +
                "signed with the debug key and must not be distributed.",
        )
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
