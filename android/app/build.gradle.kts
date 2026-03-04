plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    throw GradleException(
        "Missing signing file: ${keystorePropertiesFile.absolutePath}\n" +
            "Create it with: storeFile, storePassword, keyAlias, keyPassword"
    )
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

fun requiredKeystoreProperty(name: String): String {
    return keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "Missing or empty '$name' in key.properties required for release signing."
        )
}


android {
    namespace = "com.desarrolloytecnologiasantander.serodolfollinas"
    compileSdk = flutter.compileSdkVersion

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.desarrolloytecnologiasantander.serodolfollinas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = requiredKeystoreProperty("keyAlias")
            keyPassword = requiredKeystoreProperty("keyPassword")
            storeFile = file(requiredKeystoreProperty("storeFile"))
            storePassword = requiredKeystoreProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
