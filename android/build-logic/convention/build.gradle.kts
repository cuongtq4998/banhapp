plugins {
    `kotlin-dsl`
}

// Only the plugin APIs are needed to compile the conventions; the plugins themselves come from the main build.
dependencies {
    compileOnly(libs.android.gradle.plugin)
    compileOnly(libs.kotlin.gradle.plugin)
    compileOnly(libs.kotlin.compose.gradle.plugin)
    compileOnly(libs.kotlin.serialization.gradle.plugin)
}

gradlePlugin {
    plugins {
        register("androidLibrary") {
            id = "banh.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = "banh.android.compose"
            implementationClass = "AndroidComposeConventionPlugin"
        }
    }
}
