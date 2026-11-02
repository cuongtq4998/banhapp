plugins {
    id("banh.android.library")
    id("banh.android.compose")
}

android {
    namespace = "app.banh.core.design"
}

dependencies {
    implementation(platform(libs.compose.bom))
    api(libs.compose.ui)
    api(libs.compose.material3)

    testImplementation(libs.junit)
}
