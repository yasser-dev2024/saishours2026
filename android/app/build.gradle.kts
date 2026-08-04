import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val environmentStoreFile = System.getenv("HORSECLUB_STORE_FILE")
val environmentStorePassword = System.getenv("HORSECLUB_STORE_PASSWORD")
val environmentKeyAlias = System.getenv("HORSECLUB_KEY_ALIAS")
val environmentKeyPassword = System.getenv("HORSECLUB_KEY_PASSWORD")
val hasEnvironmentSigning = listOf(
    environmentStoreFile,
    environmentStorePassword,
    environmentKeyAlias,
    environmentKeyPassword,
).all { !it.isNullOrBlank() }
val hasReleaseSigning = keystorePropertiesFile.exists() || hasEnvironmentSigning
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseBuildRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Use scripts/build_release.ps1 with the protected Sayes Alkhayl key."
    )
}

android {
    namespace = "com.abuammar.horseclub"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.abuammar.horseclub"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                if (keystorePropertiesFile.exists()) {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                } else if (hasEnvironmentSigning) {
                    keyAlias = environmentKeyAlias
                    keyPassword = environmentKeyPassword
                    storeFile = file(environmentStoreFile!!)
                    storePassword = environmentStorePassword
                }
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
