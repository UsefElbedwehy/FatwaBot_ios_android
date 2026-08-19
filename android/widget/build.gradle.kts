plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    // Glance widgets are @Composable — without the Compose compiler plugin the
    // widget composables are compiled as plain functions (no $composer), and
    // anything that touches the Compose runtime (e.g. CompositionLocal.current)
    // fails to compile with an "internal compiler error".
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.fatwabot.widget"
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
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":core:prayer"))
    implementation(project(":core:common"))
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.runtime)
    implementation(libs.glance.appwidget)
    implementation(libs.glance.material3)
    implementation(libs.kotlinx.datetime)
    testImplementation(libs.junit)
}
