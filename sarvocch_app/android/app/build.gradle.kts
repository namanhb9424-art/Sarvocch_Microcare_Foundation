import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseSigningKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val missingReleaseSigningKeys = releaseSigningKeys.filter {
    keystoreProperties.getProperty(it)?.isNotBlank() != true
}
val releaseKeystorePath = keystoreProperties.getProperty("storeFile")?.trim()
val releaseKeystoreFile = releaseKeystorePath?.let { rootProject.file(it) }
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseBuildRequested) {
    if (!keystorePropertiesFile.isFile || missingReleaseSigningKeys.isNotEmpty()) {
        throw GradleException(
            "Release signing is required. Create android/key.properties from " +
                "android/key.properties.template and provide protected signing values."
        )
    }
    if (releaseKeystoreFile?.isFile != true) {
        throw GradleException(
            "The release keystore file configured in android/key.properties was not found."
        )
    }
}

android {
    namespace = "com.sarvocch.microcare.sarvocch_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")?.trim()
            keyPassword = keystoreProperties.getProperty("keyPassword")?.trim()
            storeFile = releaseKeystoreFile
            storePassword = keystoreProperties.getProperty("storePassword")?.trim()
        }
    }

    defaultConfig {
        applicationId = "com.sarvocch.microcare.sarvocch_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
