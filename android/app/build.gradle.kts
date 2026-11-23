import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val releaseStoreFilePath: String? = keystoreProperties.getProperty("storeFile")?.trim()?.takeIf { it.isNotEmpty() }
val releaseStorePassword: String? = keystoreProperties.getProperty("storePassword")?.trim()?.takeIf { it.isNotEmpty() }
val releaseKeyAlias: String? = keystoreProperties.getProperty("keyAlias")?.trim()?.takeIf { it.isNotEmpty() }
val releaseKeyPassword: String? = keystoreProperties.getProperty("keyPassword")?.trim()?.takeIf { it.isNotEmpty() }
val hasReleaseSigning: Boolean =
    releaseStoreFilePath != null &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

val mapsApiKey: String =
    localProperties.getProperty("MAPS_API_KEY")
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

android {
    namespace = "co.viajusta.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.viajusta.app"
        // Compatible con Google Maps SDK for Android y ML Kit Text Recognition (minSdk >= 23).
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // H-03 (OWASP M7: Insufficient Binary Protections / M8: Security Misconfiguration):
            // Deshabilita depuracion en release, activa ofuscacion y reduccion de codigo con R8
            // y aplica las reglas de preservacion en android/app/proguard-rules.pro.
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Usa android/key.properties cuando existe; respalda a debug solo en pruebas locales previas al keystore.
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
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
