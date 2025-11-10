plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mulhimiq.app"
    compileSdk = 36 // Compile against 36 to satisfy plugin/AAR requirements

    defaultConfig {
        applicationId = "com.mulhimiq.app"
        minSdk = flutter.minSdkVersion // ✅ لازم على الأقل 21 لدعم OneSignal
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // ✅ لا نستخدم R8 أو shrink الآن حتى نتأكد كل شيء يعمل
            isMinifyEnabled = false
            isShrinkResources = false
            // ⚠️ لاحقاً سنعيد تفعيلهم
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase BOM لضمان التوافق بين الإصدارات
    implementation(platform("com.google.firebase:firebase-bom:34.5.0"))

    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-messaging")
}
