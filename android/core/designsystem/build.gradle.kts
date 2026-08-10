plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.fatwabot.core.designsystem"
    compileSdk = 35

    defaultConfig {
        minSdk = 26
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
    // For the Arabic honorific expansion the shared content card applies.
    implementation(project(":core:common"))

    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    // ContentCopy, used by the shared content card's copy chip.
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.ui.tooling.preview)
    testImplementation(libs.junit)
}
