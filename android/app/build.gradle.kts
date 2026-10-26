import javax.inject.Inject

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// The API host is never committed (public repository, deployment.md section 3). It comes from the Gradle
// property `apiBaseUrl` or the environment variable `API_BASE_URL`; the fallbacks below are placeholders:
// 10.0.2.2 is the emulator's alias for the host machine, and `.invalid` can never resolve (RFC 2606).
val apiBaseUrlOverride: String? = providers.gradleProperty("apiBaseUrl")
    .orElse(providers.environmentVariable("API_BASE_URL"))
    .orNull
val debugApiBaseUrlFallback = "http://10.0.2.2:8080/"
val releaseApiBaseUrlFallback = "https://api.invalid/"

// The app resolves "v1/catalog" against this value, which therefore must end with a slash.
fun apiBaseUrlLiteral(url: String): String = "\"${if (url.endsWith("/")) url else "$url/"}\""

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
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", apiBaseUrlLiteral(apiBaseUrlOverride ?: debugApiBaseUrlFallback))
        }
        release {
            buildConfigField("String", "API_BASE_URL", apiBaseUrlLiteral(apiBaseUrlOverride ?: releaseApiBaseUrlFallback))
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
        buildConfig = true
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.okhttp)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)

    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.rules)
    // Newer than the 3.5.0 that Compose UI test brings: that one cannot idle on Android 16 (API 36).
    androidTestImplementation(libs.androidx.test.espresso.core)
    // Registers the empty activity that createComposeRule launches; debug only, so release builds do not contain it.
    debugImplementation(libs.compose.ui.test.manifest)
}

// The API contract fixtures are shared with backend and iOS; tests find them through this property
// instead of a path relative to the working directory.
tasks.withType<Test>().configureEach {
    systemProperty("contracts.fixtures.dir", rootDir.resolve("../contracts/fixtures").canonicalPath)
}

// The same fixtures reach the emulator as assets of the test APK, so the UI tests and the backend read one source.
abstract class CopyContractFixtures : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val fixtures: DirectoryProperty

    @get:OutputDirectory
    abstract val assetsDirectory: DirectoryProperty

    @get:Inject
    abstract val fileSystem: FileSystemOperations

    @TaskAction
    fun copy() {
        fileSystem.sync {
            from(fixtures)
            into(assetsDirectory)
        }
    }
}

val copyContractFixtures = tasks.register<CopyContractFixtures>("copyContractFixtures") {
    fixtures.set(rootDir.resolve("../contracts/fixtures"))
}

androidComponents.onVariants { variant ->
    variant.androidTest?.sources?.assets?.addGeneratedSourceDirectory(copyContractFixtures, CopyContractFixtures::assetsDirectory)
}
