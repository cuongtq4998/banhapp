plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    // ADR-0016: namespace and applicationId are frozen at the first store upload.
    namespace = "app.banh.customer"
    // Compose 1.12 (resolved through the BOM) requires compileSdk 37; see gradle/libs.versions.toml.
    compileSdk = 37

    defaultConfig {
        applicationId = "app.banh.customer"
        // ADR-0005: Android 8.0.
        minSdk = 26
        // Kept apart from compileSdk on purpose: raising the target opts into new runtime behaviour changes.
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit)
}

// The API contract fixtures are shared with backend and iOS; tests find them through this property
// instead of a path relative to the working directory.
tasks.withType<Test>().configureEach {
    systemProperty("contracts.fixtures.dir", rootDir.resolve("../contracts/fixtures").canonicalPath)
}
