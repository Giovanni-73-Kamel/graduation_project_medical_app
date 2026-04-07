plugins {
    id("com.android.application")
    kotlin("android") // uses version from project-level build.gradle.kts
    id("dev.flutter.flutter-gradle-plugin")
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget

android {
    namespace = "com.example.medical" // change to your package name
    compileSdk = 36 // or flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.medical" // change to your package name
        minSdk = flutter.minSdkVersion // or flutter.minSdkVersion
        targetSdk = 36 // or flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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
    // Desugaring for Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Force stable androidx versions to avoid AGP/Kotlin conflicts
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "androidx.browser" && requested.name == "browser") {
                    useVersion("1.8.0")
                }
                if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                    useVersion("1.13.1")
                }
                if (requested.group == "androidx.core" && requested.name == "core") {
                    useVersion("1.13.1")
                }
            }
        }
    }
}
