import javax.inject.Inject

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// The API host is never committed (public repository, deployment.md section 3). It comes from the Gradle property
// `adminApiBaseUrl` or the environment variable `ADMIN_API_BASE_URL`; the fallbacks are placeholders: 10.0.2.2 is the
// emulator's alias for the host machine (debug only, cleartext is allowed only for it), `.invalid` never resolves (RFC 2606).
val apiBaseUrlOverride: String? = providers.gradleProperty("adminApiBaseUrl")
    .orElse(providers.environmentVariable("ADMIN_API_BASE_URL"))
    .orNull
val debugApiBaseUrlFallback = "http://10.0.2.2:8080/"
val releaseApiBaseUrlFallback = "https://api.invalid/"

fun apiBaseUrlLiteral(url: String): String = "\"${if (url.endsWith("/")) url else "$url/"}\""

android {
    // ADR-0026: namespace and applicationId are frozen at the first upload.
    namespace = "app.banh.admin"
    compileSdk = 37

    defaultConfig {
        applicationId = "app.banh.admin"
        minSdk = 26
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

// Push (FR-25): the Firebase dependency is optional. With no `google-services.json` next to this file (the repository never holds one)
// the build uses `src/pushOff` (no token provider, push stays off). `src/pushFcm` (FCM service, token provider, Firebase Messaging and the
// google-services plugin) does not exist yet: it is written when a Firebase project exists, and is then used only when the file is present too.
val firebaseConfigured = file("google-services.json").exists() && file("src/pushFcm").exists()
android.sourceSets.getByName("main").kotlin.directories.add(if (firebaseConfigured) "src/pushFcm/kotlin" else "src/pushOff/kotlin")

dependencies {
    implementation(project(":core:design"))
    implementation(project(":core:common"))
    implementation(project(":core:network"))
    implementation(project(":core:model"))
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
    androidTestImplementation(libs.androidx.test.espresso.core)
    debugImplementation(libs.compose.ui.test.manifest)
}

tasks.withType<Test>().configureEach {
    systemProperty("contracts.fixtures.dir", rootDir.resolve("../contracts/fixtures").canonicalPath)
}

// The admin fixtures reach the debug app as assets: the debug stub backend serves them (no server needed for UI tests).
abstract class CopyAdminFixtures : DefaultTask() {
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
            into(assetsDirectory.dir("admin-fixtures"))
        }
    }
}

val copyAdminFixtures = tasks.register<CopyAdminFixtures>("copyAdminFixtures") {
    fixtures.set(rootDir.resolve("../contracts/fixtures/admin"))
}

androidComponents.onVariants(androidComponents.selector().withBuildType("debug")) { variant ->
    variant.sources.assets?.addGeneratedSourceDirectory(copyAdminFixtures, CopyAdminFixtures::assetsDirectory)
}
