plugins {
    id("banh.android.library")
}

android {
    namespace = "app.banh.core.common"
}

dependencies {
    api(project(":core:model"))
    api(libs.androidx.lifecycle.viewmodel)
    api(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
}
