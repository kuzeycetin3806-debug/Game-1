// Android library (AAR) for Şehir Nefes Alıyor local notifications.
// Built in CI: gradle -p platform/android assembleDebug assembleRelease
plugins {
    id("com.android.library") version "8.5.2"
    id("org.jetbrains.kotlin.android") version "1.9.24"
}

android {
    namespace = "com.nefeskent.notifications"
    compileSdk = 34
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Provided by the Godot app at runtime.
    compileOnly("org.godotengine:godot:4.4.1.stable")
    implementation("androidx.core:core:1.13.1")
}
