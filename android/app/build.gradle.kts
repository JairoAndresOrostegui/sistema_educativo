plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.util.Base64
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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
    namespace = "co.edu.liceobilinguerodolfollinas.sistemaeducativo"
    compileSdk = 37

    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "co.edu.liceobilinguerodolfollinas.sistemaeducativo"
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
    flavorDimensions += "environment"
    productFlavors {
        create("qa") {
            dimension = "environment"
            applicationId = "co.edu.liceobilinguerodolfollinas.sistemaeducativo"
            manifestPlaceholders["mapsApiKey"] = "AIzaSyAumcmbsvpdqMka8oLH-teuIhzsNRxYwE0"
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.desarrolloytecnologiasantander.serodolfollinas"
            manifestPlaceholders["mapsApiKey"] = providers.gradleProperty("PROD_MAPS_API_KEY").orElse("").get()
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

// Reject a Dart/native mismatch before generating an installable artifact.
val dartDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotBlank() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
val dartEnvironment = dartDefines.firstOrNull { it.startsWith("APP_ENV=") }
    ?.substringAfter("=") ?: "qa"
for (requestedTask in gradle.startParameter.taskNames) {
    val taskName = requestedTask.substringAfterLast(":")
    val nativeEnvironment = when {
        taskName.contains("Prod") -> "prod"
        taskName.contains("Qa") -> "qa"
        else -> null
    }
    if (nativeEnvironment != null && dartEnvironment != nativeEnvironment) {
        throw GradleException("APP_ENV=$dartEnvironment does not match flavor $nativeEnvironment")
    }
}
androidComponents {
    beforeVariants(selector().all()) { variant ->
        variant.enable = variant.productFlavors.any {
            it.first == "environment" && it.second == dartEnvironment
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
