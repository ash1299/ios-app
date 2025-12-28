import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.sevak_app"
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
        applicationId = "com.example.sevak_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            val props = Properties()
            if (keyPropertiesFile.exists()) {
                FileInputStream(keyPropertiesFile).use { props.load(it) }
            }

            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
            storeFile = props.getProperty("storeFile")?.let { file(it) }
            storePassword = props.getProperty("storePassword")
            
            // --- FIX 1: ENABLE SIGNING FOR INSTALLATION ---
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }

    // --- FIX 2: FORCE STABLE DEPENDENCIES FOR BUILD ---
    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
        }
    }
}

// Ensure Flutter can find the APK
tasks.register("copyReleaseApk") {
    doLast {
        val apkFile = file("${project.buildDir}/outputs/apk/release/app-release.apk")
        val repoRoot = projectDir.parentFile.parentFile 
        val destDir = file("${repoRoot.absolutePath}/build/app/outputs/flutter-apk/")
        if (apkFile.exists()) {
            destDir.mkdirs()
            copy {
                from(apkFile)
                into(destDir)
            }
            println("Copied release APK to: ${destDir.absolutePath}")
        } else {
            println("Release APK not found at: ${apkFile.absolutePath}")
        }
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("copyReleaseApk")
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
}