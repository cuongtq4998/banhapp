plugins {
    id("banh.android.library")
}

android {
    namespace = "app.banh.core.model"
}

dependencies {
    api(libs.kotlinx.serialization.json)

    testImplementation(libs.junit)
}
