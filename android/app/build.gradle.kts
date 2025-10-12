plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // ✅ بدون version هنا
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mulhimiq.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.mulhimiq.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // ✅ Firebase Messaging (مطلوب لـ OneSignal)
    implementation("com.google.firebase:firebase-messaging")

    // ✅ Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
}
