plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.android_wifi_scanner"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.android_wifi_scanner"
        minSdk = 23  // ✅ Changed from 26 to 21 (Firebase minimum requirement)
        targetSdk = 35
        multiDexEnabled = true
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // ✅ Firebase BoM (Bill of Materials)
    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))
    
    // ✅ Firebase dependencies (no version needed with BoM)
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-analytics")  // Optional but recommended
    
    // ✅ AndroidX dependencies (consistent Kotlin DSL syntax)
    implementation("androidx.core:core-ktx:1.12.0") {
        exclude(group = "android.support", module = "support-v4")
    }
    implementation("androidx.appcompat:appcompat:1.6.1") {
        exclude(group = "android.support", module = "support-v4")
    }
    implementation("com.google.android.material:material:1.11.0") {
        exclude(group = "android.support", module = "support-v4")
    }
    implementation("androidx.constraintlayout:constraintlayout:2.1.4") {
        exclude(group = "android.support", module = "support-v4")
    }
    
    // ✅ MultiDex for Firebase
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ✅ Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // ✅ Desugaring for Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}